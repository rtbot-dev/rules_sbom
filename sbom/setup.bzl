"""Convenience setup helpers for rules_sbom."""

_TOOLCHAIN_LABELS = {
    "darwin_amd64": "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
    "darwin_arm64": "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
    "linux_amd64": "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
    "linux_arm64": "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
    "windows_amd64": "@rules_sbom//toolchains/syft:windows_amd64_toolchain",
}

def rules_sbom_setup(syft_repo_rule, version = "1.17.0", platforms = None):
    """Registers Syft repositories and toolchains with sensible defaults.

    Args:
        syft_repo_rule: The repo rule returned by `use_repo_rule`.
        version: Syft release version to download.
        platforms: Optional iterable of platform keys ("<os>_<arch>").
    """
    if platforms == None:
        platforms = [
            "darwin_amd64",
            "darwin_arm64",
            "linux_amd64",
            "linux_arm64",
            "windows_amd64",
        ]

    repos = []
    toolchains = []
    for platform in platforms:
        if not isinstance(platform, str) or "_" not in platform:
            fail("rules_sbom_setup: platform '{}' must be a string like 'os_arch'".format(platform))
        repo_name = "rules_sbom_syft_{}".format(platform)
        syft_repo_rule(
            name = repo_name,
            version = version,
            platform = platform,
        )
        repos.append(repo_name)

        label = _TOOLCHAIN_LABELS.get(platform)
        if label:
            toolchains.append(label)

    if toolchains:
        native.register_toolchains(*toolchains)

    return repos
