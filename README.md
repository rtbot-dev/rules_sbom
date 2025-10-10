# rules_sbom

`rules_sbom` provides Bazel rules for generating Software Bill of Materials (SBOM) artifacts from Bazel targets using best-in-class external tooling.

> ⚠️ This repository is under active development. The public APIs and toolchain integrations are not yet stable.

## Getting started

1. Add the dependency in `MODULE.bazel`:
   ```starlark
   bazel_dep(name = "rules_sbom", version = "<release>")
   ```
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
