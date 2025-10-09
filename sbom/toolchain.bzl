"""Toolchain registration helpers for rules_sbom."""

def rules_sbom_register_toolchains():
    """Registers the default SBOM toolchains."""
    native.register_toolchains("@rules_sbom//toolchains/syft:toolchain")
