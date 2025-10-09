# Usage

Add the dependency in `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_sbom", version = "<release>")
```

Provision the default Syft toolchain via the bundled repository rule:

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

Instantiate only the platforms you plan to use—e.g., omit macOS entries on a Linux-only fleet. The repository rule ships with default SHA256 sums for these platforms; override `sha256` or `version` if you pin alternative binaries.

Generate an SBOM for a target:

```starlark
load("@rules_sbom//sbom:defs.bzl", "sbom_artifact")

sbom_artifact(
    name = "my_binary_sbom",
    target = "//service:binary",
    format = "cyclonedx_json",
)
```

The resulting file is written to `bazel-bin/service/my_binary_sbom/sbom.json` (path may vary depending on the output filename).
