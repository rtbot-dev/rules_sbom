# rules_sbom

[![Release](https://img.shields.io/github/v/release/rtbot-dev/rules_sbom?label=Release&logo=github)](https://github.com/rtbot-dev/rules_sbom/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/rtbot-dev/rules_sbom/ci.yml?label=CI&logo=github)](https://github.com/rtbot-dev/rules_sbom/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rtbot-dev/rules_sbom?label=License&color=blue)](LICENSE)
[![Bazel](https://img.shields.io/badge/Bazel-43A047?logo=Bazel&logoColor=white)](https://bazel.build/)

`rules_sbom` provides Bazel rules for generating Software Bill of Materials (SBOM) artifacts from Bazel targets using best-in-class external tooling.

> ⚠️ This repository is under active development. The public APIs and toolchain integrations are not yet stable.

## Getting started

1. Add the dependency in `MODULE.bazel`. Until this module lands in the Bazel Central Registry, pin the GitHub release with an override:
   ```starlark
   bazel_dep(name = "rules_sbom", version = "0.4.2")

   archive_override(
       module_name = "rules_sbom",
       urls = ["https://github.com/rtbot-dev/rules_sbom/archive/refs/tags/v0.4.2.tar.gz"],
       strip_prefix = "rules_sbom-0.4.2",
       sha256 = "481cdf1bf8d585aa1c3b60b6741e245ee313bdc8c354cab8999ac53f9bb24ced",
   )
   ```
   Update the version and checksum whenever you move to a newer release.
2. Provision the bundled Syft toolchain with built-in defaults:
   ```starlark
   load("@rules_sbom//sbom:setup.bzl", "rules_sbom_setup")

   syft_repo = use_repo_rule("@rules_sbom//sbom:repositories.bzl", "syft_repository")
   rules_sbom_setup(syft_repo)
   ```
   The setup helper preinstalls Syft for macOS (amd64/arm64), Linux (amd64/arm64), and Windows (amd64) with default SHA256 sums. Override the platforms, version, or SHA via `rules_sbom_setup(..., platforms=[...], version="...")` if needed.
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

## Release workflow

Releases are automated with Release Please. Conventional commits drive the next version:

- `feat:` bumps the minor version while we are pre-1.0.
- `fix:` (or other non-feature commits) bumps the patch version.
- Commits with `BREAKING CHANGE:` or a `!` trigger a major bump.

Once changes land on `main`, the GitHub action opens a release PR. Merging that PR tags `vX.Y.Z`, publishes the GitHub release, and the `Verify Release Tag` workflow confirms that the tag matches the version declared in `MODULE.bazel`.

If you need to double-check a release manually, re-run the `Release Please` workflow from the Actions tab; it will only open a new PR when there are user-facing commits since the last tag.

Use `bazel sync` after upgrading to ensure the Syft toolchain archives download for your host platform; this refreshes the Syft binaries for the host OS/architecture and avoids stale CLI binaries across machines.

Every published release now includes ready-to-copy install snippets (Bzlmod and WORKSPACE) directly in the GitHub release notes for easy onboarding. If you need to pin Syft to a different version, call `rules_sbom_setup(..., version="<syft_version>")` in your workspace or MODULE file.
