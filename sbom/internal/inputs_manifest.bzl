"""Helpers for constructing SBOM action input manifests."""

def build_inputs_manifest(files, config_file):
    """Renders the input manifest given the transitive file set.

    Args:
        files: depset of File objects to stage for analysis.
        config_file: Optional File object for the config.

    Returns:
        A newline separated string containing "<absolute_path>\t<short_path>" entries.
    """
    entries = {}

    for f in files.to_list():
        entries[f.short_path] = f.path

    if config_file:
        entries[config_file.short_path] = config_file.path

    if not entries:
        return ""

    lines = []
    for short_path in sorted(entries.keys()):
        lines.append("{}\t{}".format(entries[short_path], short_path))

    return "\n".join(lines) + "\n"
