# rules_sbom

`rules_sbom` provides Bazel rules for generating Software Bill of Materials (SBOM) artifacts from Bazel targets using best-in-class external tooling.

> ⚠️ This repository is under active development. The public APIs and toolchain integrations are not yet stable.

## Getting started

1. Add the dependency in `MODULE.bazel`:
   ```starlark
   bazel_dep(name = "rules_sbom", version = "<release>")
   ```
2. Provision the bundled Syft toolchain:
   ```starlark
   syft_repo = use_repo_rule("@rules_sbom//sbom:repositories.bzl", "syft_repository")
   for platform in ("darwin_amd64", "darwin_arm64", "linux_amd64", "linux_arm64"):
       syft_repo(
           name = "rules_sbom_syft_{}".format(platform),
           version = "1.17.0",
           platform = platform,
       )

   register_toolchains(
       "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
       "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
       "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
       "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
   )
   ```
   The repository rule embeds default SHA256 sums for these OS/CPU pairs; pass `sha256 = "..."` (and/or adjust `version`) to supply custom binaries.
3. Define SBOM targets:
   ```starlark
   load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

   sbom_artifact(
       name = "my_binary_sbom",
       target = "//service:binary",
   )
   ```

The [`docs/`](docs/overview.md) directory contains more detailed usage and toolchain notes.

## Examples

- Python (basic): [`examples/python`](examples/python/BUILD.bazel)
- Python (lockfile with transitive deps): [`examples/python_complex`](examples/python_complex/BUILD.bazel)
- Go (basic): [`examples/go`](examples/go/BUILD.bazel)
- Go (cobra CLI with transitive deps): [`examples/go_complex`](examples/go_complex/BUILD.bazel)
- Node.js (basic): [`examples/node`](examples/node/BUILD.bazel)
- Node.js (express app with transitive deps): [`examples/node_complex`](examples/node_complex/BUILD.bazel)
