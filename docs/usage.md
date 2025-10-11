# Usage

Add the dependency in `MODULE.bazel`. Until `rules_sbom` is listed in the Bazel Central Registry, pin the GitHub release with an override:

```starlark
bazel_dep(name = "rules_sbom", version = "0.4.5")

archive_override(
    module_name = "rules_sbom",
    urls = ["https://github.com/rtbot-dev/rules_sbom/archive/refs/tags/v0.4.5.tar.gz"],
    strip_prefix = "rules_sbom-0.4.5",
    sha256 = "<sha256>",
)
```

Update the version and checksum whenever you upgrade to a newer release.

Provision the default Syft toolchain via the bundled module extension:

```starlark
sbom_ext = use_extension("@rules_sbom//sbom:extensions.bzl", "sbom_setup")
```

The extension installs Syft for macOS (amd64/arm64), Linux (amd64/arm64), and Windows (amd64) with baked-in SHA256 sums. To customize the download set, write a small wrapper extension that calls `rules_sbom_setup(..., version = "1.18.0", platforms = ["linux_amd64"])`.

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
