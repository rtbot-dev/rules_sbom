"""Module extensions for configuring rules_sbom dependencies."""

load("//sbom:repositories.bzl", "DEFAULT_SYFT_VERSION", "SYFT_PLATFORMS", "syft_repository")

_syft = tag_class(
    attrs = {
        "version": attr.string(
            doc = "Syft release version to download.",
            default = DEFAULT_SYFT_VERSION,
        ),
        "sha256": attr.string_dict(
            doc = "Archive sha256 per platform key ('<os>_<arch>'). Required for every platform when version is not the default.",
        ),
    },
    doc = "Overrides the Syft release used by the bundled toolchains. Only the root module's tag is honored.",
)

def _select_syft_tag(module_ctx):
    for mod in module_ctx.modules:
        if not mod.is_root:
            continue
        if len(mod.tags.syft) > 1:
            fail("sbom_setup: only one sbom_setup.syft() tag is allowed in the root module")
        if mod.tags.syft:
            return mod.tags.syft[0]
    return None

def _sbom_setup_impl(module_ctx):
    tag = _select_syft_tag(module_ctx)
    version = tag.version if tag else DEFAULT_SYFT_VERSION
    sha256 = tag.sha256 if tag else {}

    unknown = [key for key in sha256 if key not in SYFT_PLATFORMS]
    if unknown:
        fail("sbom_setup: unknown platform keys {} (expected any of {})".format(unknown, SYFT_PLATFORMS))

    for platform in SYFT_PLATFORMS:
        syft_repository(
            name = "rules_sbom_syft_{}".format(platform),
            platform = platform,
            version = version,
            sha256 = sha256.get(platform, ""),
        )

sbom_setup = module_extension(
    implementation = _sbom_setup_impl,
    tag_classes = {"syft": _syft},
    doc = "Downloads the Syft binaries used by the bundled rules_sbom toolchains.",
)
