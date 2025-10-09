"""Public rule definitions for rules_sbom."""

load("//sbom/internal:sbom_artifact.bzl", _sbom_artifact = "sbom_artifact")

def sbom_artifact(*, name, target, format = "cyclonedx_json", output = "sbom.json", config = None, visibility = None, tags = None, **kwargs):
    """Generates an SBOM artifact for the given target.

    Args:
        name: Target name.
        target: Label to analyze for dependency metadata.
        format: SBOM output format identifier.
        output: Output filename to register.
        config: Optional tool configuration file.
        visibility: Optional visibility settings.
        tags: Optional tags propagated to the generated target.
        **kwargs: Forwarded to the underlying implementation rule.
    """
    return _sbom_artifact(
        name = name,
        target = target,
        format = format,
        output = output,
        config = config,
        visibility = visibility,
        tags = tags,
        **kwargs
    )
