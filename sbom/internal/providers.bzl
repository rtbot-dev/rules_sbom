"""Provider definitions for rules_sbom."""

SbomInfo = provider(
    doc = "Carries the generated SBOM artifact and associated metadata.",
    fields = {
        "sbom": "Output File containing the generated SBOM.",
        "format": "Format string passed to the generator.",
        "target": "Label that served as the analysis root.",
    },
)

SbomToolchainInfo = provider(
    doc = "Describes an SBOM generation toolchain.",
    fields = {
        "tool": "Executable used to generate SBOMs.",
        "default_format": "Default format emitted by the tool.",
        "env": "Dictionary of environment variables applied at execution.",
        "supports_formats": "List of formats supported by this toolchain.",
        "wrapper": "Optional wrapper executable for preprocessing.",
    },
)
