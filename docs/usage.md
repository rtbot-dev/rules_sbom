# Usage

Add the dependency in `MODULE.bazel`. Until `rules_sbom` is listed in the Bazel Central Registry, pin the GitHub release with an override:

```starlark
bazel_dep(name = "rules_sbom", version = "0.4.2")

archive_override(
    module_name = "rules_sbom",
    urls = ["https://github.com/rtbot-dev/rules_sbom/archive/refs/tags/v0.4.2.tar.gz"],
    strip_prefix = "rules_sbom-0.4.2",
    sha256 = "481cdf1bf8d585aa1c3b60b6741e245ee313bdc8c354cab8999ac53f9bb24ced",
)
```

Update the version and checksum whenever you upgrade to a newer release.

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
