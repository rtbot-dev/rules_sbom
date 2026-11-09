"""Convenience setup helpers for rules_sbom."""

load("//sbom:repositories.bzl", "DEFAULT_SYFT_VERSION", "SYFT_PLATFORMS")

_TOOLCHAIN_LABELS = {
    "darwin_amd64": "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
    "darwin_arm64": "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
    "linux_amd64": "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
    "linux_arm64": "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
    "windows_amd64": "@rules_sbom//toolchains/syft:windows_amd64_toolchain",
}

def rules_sbom_setup(
        syft_repo_rule,
        version = DEFAULT_SYFT_VERSION,
        platforms = None,
        register_toolchains = True,
        sha256 = None):
    """Registers Syft repositories and toolchains with sensible defaults.

    Args:
        syft_repo_rule: The repo rule returned by `use_repo_rule`.
        version: Syft release version to download.
        platforms: Optional iterable of platform keys ("<os>_<arch>").
        register_toolchains: Whether to register the bundled toolchains.
        sha256: Optional dict of platform key to archive sha256; needed for non-default versions.

    Returns:
        List of the created repository names.
    """
    if platforms == None:
        platforms = SYFT_PLATFORMS
    sha256 = sha256 or {}

    repos = []
    toolchains = []
    for platform in platforms:
        if type(platform) != "string" or "_" not in platform:
            fail("rules_sbom_setup: platform '{}' must be a string like 'os_arch'".format(platform))
        repo_name = "rules_sbom_syft_{}".format(platform)
        syft_repo_rule(
            name = repo_name,
            version = version,
            platform = platform,
            sha256 = sha256.get(platform, ""),
        )
        repos.append(repo_name)

        label = _TOOLCHAIN_LABELS.get(platform)
        if label:
            toolchains.append(label)

    if register_toolchains and toolchains:
        native.register_toolchains(*toolchains)

    return repos
