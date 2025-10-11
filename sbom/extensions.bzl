"""Module extensions for configuring rules_sbom dependencies."""

load("//sbom:repositories.bzl", "syft_repository")
load("//sbom:setup.bzl", "rules_sbom_setup")

def _sbom_setup_impl(module_ctx):
    rules_sbom_setup(syft_repository)

sbom_setup = module_extension(
    implementation = _sbom_setup_impl,
    doc = "Registers Syft repositories and toolchains using rules_sbom defaults.",
)
