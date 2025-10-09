"""Repository helper macros for rules_sbom."""

_SYFT_ARTIFACTS = {
    ("linux", "amd64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_linux_amd64.tar.gz",
        "strip_prefix": "",
        "sha256": "3485e831c21fd80b41fa3fc1f72e10367989b2d1aee082d642b5b0e658a02b44",
    },
    ("linux", "arm64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_linux_arm64.tar.gz",
        "strip_prefix": "",
        "sha256": "7f3e0cf3f8bc5dc320e56b0e133c854c8000d5f473bd61d247341a1b7bfa27ea",
    },
    ("darwin", "amd64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_darwin_amd64.tar.gz",
        "strip_prefix": "",
        "sha256": "81fb22678eba3380c28e0f425e0e7ff0a41ba57a8e1e98825ad92a7fa5698c78",
    },
    ("darwin", "arm64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_darwin_arm64.tar.gz",
        "strip_prefix": "",
        "sha256": "2cb79ecdc62d453912e299e7b814107700250ffeffdb3a9ea5dc9099af7b6dba",
    },
}

def _normalize_os(name):
    if name in ("mac os x", "darwin"):
        return "darwin"
    return name

def _normalize_arch(arch):
    if arch in ("x86_64",):
        return "amd64"
    if arch in ("aarch64",):
        return "arm64"
    return arch

def _syft_repository_impl(repo_ctx):
    version = repo_ctx.attr.version
    if repo_ctx.attr.platform:
        platform = repo_ctx.attr.platform
        if "_" in platform:
            os_name, arch = platform.split("_", 1)
        else:
            fail("rules_sbom: platform '{}' should be in '<os>_<arch>' form".format(platform))
    else:
        os_name = _normalize_os(repo_ctx.os.name)
        arch = _normalize_arch(repo_ctx.os.arch)
        platform = "{}_{}".format(os_name, arch)

    os_name = _normalize_os(os_name)
    arch = _normalize_arch(arch)
    host_key = (os_name, arch)
    artifact = _SYFT_ARTIFACTS.get(host_key)
    if not artifact:
        fail("rules_sbom: unsupported platform '{}'".format(platform))

    url = artifact["url"].format(version = version)
    strip_prefix = artifact["strip_prefix"].format(version = version)
    kwargs = {"url": url}
    sha_override = repo_ctx.attr.sha256
    if sha_override:
        kwargs["sha256"] = sha_override
    elif artifact.get("sha256"):
        kwargs["sha256"] = artifact["sha256"]
    if strip_prefix:
        kwargs["stripPrefix"] = strip_prefix

    repo_ctx.download_and_extract(**kwargs)

    repo_ctx.file(
        "BUILD.bazel",
        content = 'exports_files(["syft"], visibility = ["//visibility:public"])\n',
    )

syft_repository = repository_rule(
    implementation = _syft_repository_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "Syft release version to download.",
        ),
        "sha256": attr.string(
            doc = "Optional SHA256 of the Syft archive for this host platform.",
        ),
        "platform": attr.string(
            doc = "Platform key '<os>_<arch>' to download explicitly (optional).",
        ),
    },
    doc = "Downloads the Syft CLI binary for the current host platform.",
)

def rules_sbom_toolchains():
    """Registers the default Syft-backed toolchain."""
    native.register_toolchains(
        "@rules_sbom//toolchains/syft:darwin_amd64_toolchain",
        "@rules_sbom//toolchains/syft:darwin_arm64_toolchain",
        "@rules_sbom//toolchains/syft:linux_amd64_toolchain",
        "@rules_sbom//toolchains/syft:linux_arm64_toolchain",
    )
