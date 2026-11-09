"""Public rule definitions for rules_sbom."""

load("//sbom/internal:sbom_artifact.bzl", _sbom_artifact = "sbom_artifact")

def sbom_artifact(
        *,
        name,
        target,
        format = "cyclonedx_json",
        output = "sbom.json",
        config = None,
        scheme = "dir",
        syft_args = [],
        source_name = None,
        source_version = None,
        allow_placeholder = False,
        visibility = None,
        tags = None,
        **kwargs):
    """Generates an SBOM artifact for the given target.

    Args:
        name: Target name.
        target: Label to analyze for dependency metadata.
        format: SBOM output format identifier.
        output: Output filename to register.
        config: Optional tool configuration file.
        scheme: "dir" scans the staged files; "oci-dir" scans the target's single output directory as an OCI image layout.
        syft_args: Extra arguments appended to the syft command line, e.g. ["--platform", "linux/arm64"].
        source_name: Name recorded for the scanned source. Defaults to the target label.
        source_version: Optional version recorded for the scanned source.
        allow_placeholder: Write a placeholder SBOM instead of failing when syft errors.
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
        scheme = scheme,
        syft_args = syft_args,
        source_name = source_name,
        source_version = source_version,
        allow_placeholder = allow_placeholder,
        visibility = visibility,
        tags = tags,
        **kwargs
    )
