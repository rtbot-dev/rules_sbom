# rules_sbom

[![Release](https://img.shields.io/github/v/release/rtbot-dev/rules_sbom?label=Release&logo=github)](https://github.com/rtbot-dev/rules_sbom/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/rtbot-dev/rules_sbom/ci.yml?label=CI&logo=github)](https://github.com/rtbot-dev/rules_sbom/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rtbot-dev/rules_sbom?label=License&color=blue)](LICENSE)
[![Bazel](https://img.shields.io/badge/Bazel-43A047?logo=Bazel&logoColor=white)](https://bazel.build/)

`rules_sbom` provides Bazel rules for generating Software Bill of Materials (SBOM) artifacts from Bazel targets using best-in-class external tooling.

> ⚠️ This repository is under active development. The public APIs and toolchain integrations are not yet stable.

## Getting started

1. Add the dependency in `MODULE.bazel`. Until this module lands in the Bazel Central Registry, pin the GitHub release with this override snippet:
   ```starlark
   bazel_dep(name = "rules_sbom", version = "0.5.1")  # x-release-please-version

   archive_override(
       module_name = "rules_sbom",
       urls = ["https://github.com/rtbot-dev/rules_sbom/archive/refs/tags/v0.5.1.tar.gz"],  # x-release-please-version
       strip_prefix = "rules_sbom-0.5.1",  # x-release-please-version
       sha256 = "011146723a36380e907548defc9ed352bbe22d2ddc7ac320cede4162ad9dd89e",
   )
   ```
   Update the version and checksum whenever you move to a newer release.
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

## Examples

- Python (basic): [`examples/python`](examples/python/BUILD.bazel)
- Python (lockfile with transitive deps): [`examples/python_complex`](examples/python_complex/BUILD.bazel)
- Go (basic): [`examples/go`](examples/go/BUILD.bazel)
- Go (cobra CLI with transitive deps): [`examples/go_complex`](examples/go_complex/BUILD.bazel)
- Node.js (basic): [`examples/node`](examples/node/BUILD.bazel)
- Node.js (express app with transitive deps): [`examples/node_complex`](examples/node_complex/BUILD.bazel)
- JavaScript / pnpm monorepo scenarios:
  - Service/package SBOM: point `sbom_artifact` at the Bazel binary target (for example a `js_binary`). The Syft wrapper stages only that target's runfiles, synthesises a scoped `package.json`/`package-lock.json`, and disables GitHub Action catalogers, so the SBOM lists just the dependencies that ship with the service.
  - Whole-repo SBOM: collect the workspace-level pnpm state into a `filegroup` and wrap it with `sbom_artifact`:

    ```starlark
    load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

    filegroup(
        name = "workspace_inputs",
        srcs = [
            "//:node_modules",
            "//:package.json",
            "//:pnpm-lock.yaml",
        ],
    )

    sbom_artifact(
        name = "workspace_sbom",
        target = ":workspace_inputs",
    )
    ```

    Building this target produces a CycloneDX SBOM that aggregates every dependency resolved across the pnpm workspace.
- Go services:
  - Service-level SBOMs can include the compiled binary together with module metadata. One approach is to create a `filegroup` that contains the service binary plus `go.mod`/`go.sum`, then pass that group to `sbom_artifact` so Syft enumerates the transitive Go modules.
  - Workspace-level SBOMs can reuse the same `filegroup` pattern as the pnpm example above: add the repository `go.mod`/`go.sum` (and any additional module manifests) alongside the Node.js inputs before invoking `sbom_artifact`.

## Release workflow

Releases are automated with Release Please. Conventional commits drive the next version:

- `feat:` bumps the minor version while we are pre-1.0.
- `fix:` (or other non-feature commits) bumps the patch version.
- Commits with `BREAKING CHANGE:` or a `!` trigger a major bump.

Once changes land on `main`, the GitHub action opens a release PR. Merging that PR tags `vX.Y.Z`, publishes the GitHub release, and the `Verify Release Tag` workflow confirms that the tag matches the version declared in `MODULE.bazel`.

If you need to double-check a release manually, re-run the `Release Please` workflow from the Actions tab; it will only open a new PR when there are user-facing commits since the last tag.

Use `bazel sync` after upgrading to ensure the Syft toolchain archives download for your host platform; this refreshes the Syft binaries for the host OS/architecture and avoids stale CLI binaries across machines.

Every published release now includes ready-to-copy install snippets (Bzlmod and WORKSPACE) directly in the GitHub release notes for easy onboarding. If you need to pin Syft to a different version, call `rules_sbom_setup(..., version="<syft_version>")` from a custom module extension or in your WORKSPACE.
