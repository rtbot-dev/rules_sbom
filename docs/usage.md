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

register_toolchains(
    "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
    "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
    "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
    "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
    "@rules_sbom//toolchains/syft:windows_amd64_toolchain",
)
```

The extension installs Syft for macOS (amd64/arm64), Linux (amd64/arm64), and Windows (amd64) with baked-in SHA256 sums. To use another Syft release, add `sbom_ext.syft(version = "...", sha256 = {"<os>_<arch>": "..."})` in the root module (see the README).

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
