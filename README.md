# rules_sbom

[![Release](https://img.shields.io/github/v/release/rtbot-dev/rules_sbom?label=Release&logo=github)](https://github.com/rtbot-dev/rules_sbom/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/rtbot-dev/rules_sbom/ci.yml?label=CI&logo=github)](https://github.com/rtbot-dev/rules_sbom/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rtbot-dev/rules_sbom?label=License&color=blue)](LICENSE)
[![Bazel](https://img.shields.io/badge/Bazel-43A047?logo=Bazel&logoColor=white)](https://bazel.build/)

`rules_sbom` provides Bazel rules for generating Software Bill of Materials (SBOM) artifacts from Bazel targets using best-in-class external tooling.

The rules are production-ready and currently power SBOM generation in real workloads. They ship reproducible CycloneDX documents that track the dependencies that actually ship with your services as well as full workspace inventories.

## Capabilities

- Service-level SBOMs: point `sbom_artifact` at a single Bazel target (for example a binary, image, or library bundle) to enumerate only the artifacts that deploy with that unit.
- Workspace-level SBOMs: aggregate manifests and lockfiles across the repository to emit a global view of every resolved dependency.
- JavaScript and pnpm monorepos: the Syft wrapper synthesizes scoped `package.json` and lockfiles for each target, disables noisy catalogers, and can also ingest workspace-level node modules so you can switch between per-service and whole-repo reports.
- Bundled Syft toolchain: pre-built binaries for macOS, Linux, and Windows ensure consistent output in CI and on developer machines.

## Getting started

1. Add the dependency in `MODULE.bazel`:
   ```starlark
   bazel_dep(name = "rules_sbom", version = "0.6.2")  # x-release-please-version
   ```
   The module is published to the [Bazel Central Registry](https://registry.bazel.build/modules/rules_sbom).
2. Provision the bundled Syft toolchain with built-in defaults:
   ```starlark
   sbom_ext = use_extension("@rules_sbom//sbom:extensions.bzl", "sbom_setup")

   register_toolchains(
       "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
       "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
       "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
       "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
       "@rules_sbom//toolchains/syft:windows_amd64_toolchain",
   )
   ```
   The extension preinstalls Syft for macOS (amd64/arm64), Linux (amd64/arm64), and Windows (amd64) with default SHA256 sums. To customize the download set, create a small wrapper extension that calls `rules_sbom_setup(..., platforms=[...], version="...", register_toolchains = False)` and register the desired toolchains explicitly.
3. Define SBOM targets:
   ```starlark
   load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

   sbom_artifact(
       name = "my_binary_sbom",
       target = "//service:binary",
   )
   ```

The [`docs/`](docs/overview.md) directory contains more detailed usage and toolchain notes (including [Windows testing via Parallels CLI](docs/windows_parallels.md)).

## Generating SBOMs

### Service-level SBOMs

The simplest configuration points `sbom_artifact` at the Bazel target you ship. The rule stages that target's runfiles, injects any language-specific metadata (for example `package.json`, `go.mod`, or `requirements.txt`), and hands the curated bundle to Syft:

```starlark
load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

sbom_artifact(
    name = "payment_service_sbom",
    target = "//services/payment:binary",
)
```

### Workspace-level SBOMs

To capture a global view, wrap the manifests, lockfiles, and other workspace inputs you care about in a `filegroup`, then ask `sbom_artifact` to process that group:

```starlark
load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

filegroup(
    name = "workspace_inputs",
    srcs = [
        "//:requirements.txt",
        "//:poetry.lock",
        "//:go.mod",
        "//:go.sum",
    ],
)

sbom_artifact(
    name = "workspace_sbom",
    target = ":workspace_inputs",
)
```

This pattern works for any combination of languages—add whatever manifests make sense for your repository.

### JavaScript and pnpm workspaces

JavaScript targets receive additional handling so you can switch between service and workspace scopes without manual staging:

- **Service SBOMs**: point `sbom_artifact` at the Bazel binary (for example a `js_binary`). The wrapper reduces the runfiles to the service's published assets, synthesizes a scoped `package.json`/`package-lock.json`, and disables unrelated catalogers so the SBOM contains only the dependencies that ship with that service.
- **Workspace SBOMs**: collect the node workspace inputs and hand them to `sbom_artifact` for a holistic view:

  ```starlark
  load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

  filegroup(
      name = "pnpm_workspace_inputs",
      srcs = [
          "//:node_modules",
          "//:package.json",
          "//:pnpm-lock.yaml",
      ],
  )

  sbom_artifact(
      name = "pnpm_workspace_sbom",
      target = ":pnpm_workspace_inputs",
  )
  ```

Both modes produce CycloneDX documents tailored to pnpm monorepos without cross-service dependency bleed.

## Examples

- Python (basic): [`examples/python`](examples/python/BUILD.bazel)
- Python (lockfile with transitive deps): [`examples/python_complex`](examples/python_complex/BUILD.bazel)
- Go (basic): [`examples/go`](examples/go/BUILD.bazel)
- Go (cobra CLI with transitive deps): [`examples/go_complex`](examples/go_complex/BUILD.bazel)
- Node.js (basic): [`examples/node`](examples/node/BUILD.bazel)
- Node.js (express app with transitive deps): [`examples/node_complex`](examples/node_complex/BUILD.bazel)

Each example maps directly onto the service-level recipe above; combine the manifests you need to produce a workspace-level SBOM.

## Release workflow

Releases are automated with Release Please. Conventional commits drive the next version:

- `feat:` bumps the minor version while we are pre-1.0.
- `fix:` (or other non-feature commits) bumps the patch version.
- Commits with `BREAKING CHANGE:` or a `!` trigger a major bump.

Once changes land on `main`, the GitHub action opens a release PR. Merging that PR tags `vX.Y.Z`, publishes the GitHub release, and the `Verify Release Tag` workflow confirms that the tag matches the version declared in `MODULE.bazel`.

If you need to double-check a release manually, re-run the `Release Please` workflow from the Actions tab; it will only open a new PR when there are user-facing commits since the last tag.

Use `bazel sync` after upgrading to ensure the Syft toolchain archives download for your host platform; this refreshes the Syft binaries for the host OS/architecture and avoids stale CLI binaries across machines.

Every published release now includes ready-to-copy install snippets (Bzlmod and WORKSPACE) directly in the GitHub release notes for easy onboarding. If you need to pin Syft to a different version, call `rules_sbom_setup(..., version="<syft_version>")` from a custom module extension or in your WORKSPACE.
