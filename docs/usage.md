# Usage

Add the dependency in `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_sbom", version = "<release>")
```

Provision the default Syft toolchain via the bundled repository rule:

```starlark
load("@rules_sbom//sbom:setup.bzl", "rules_sbom_setup")

syft_repo = use_repo_rule("@rules_sbom//sbom:repositories.bzl", "syft_repository")
rules_sbom_setup(syft_repo)
```

`rules_sbom_setup` installs Syft for macOS (amd64/arm64), Linux (amd64/arm64), and Windows (amd64) with baked-in SHA256 sums. Provide `platforms=[...]`, `version="..."`, or `sha256="..."` in the call if you need tailored downloads.

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
