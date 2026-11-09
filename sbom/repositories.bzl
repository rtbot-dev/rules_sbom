"""Repository helper macros for rules_sbom."""

_SYFT_ARTIFACTS = {
    ("linux", "amd64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_linux_amd64.tar.gz",
        "strip_prefix": "",
        "sha256": "bb65249542db5fedeeb4d3f9b018b75e7264dbfbbb10486f044581a92f90490d",
        "binary": "syft",
    },
    ("linux", "arm64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_linux_arm64.tar.gz",
        "strip_prefix": "",
        "sha256": "929bd163db2d7cd2255d3bcb8967208079813d7b46b0c952f7b794d8e2c7d304",
        "binary": "syft",
    },
    ("darwin", "amd64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_darwin_amd64.tar.gz",
        "strip_prefix": "",
        "sha256": "e2e5831cbabaec9a36fe65c34755c1113982c842a685edce3ce0b54a0ded8003",
        "binary": "syft",
    },
    ("darwin", "arm64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_darwin_arm64.tar.gz",
        "strip_prefix": "",
        "sha256": "1217c258bd5eb91ef3189cf22a82e02f9cac07e4ce934350f428e93aff674625",
        "binary": "syft",
    },
    ("windows", "amd64"): {
        "url": "https://github.com/anchore/syft/releases/download/v{version}/syft_{version}_windows_amd64.zip",
        "strip_prefix": "",
        "sha256": "ada4c9b93af575f479ce80fce6629897272a2d41f300a14bc49bace020767ca2",
        "binary": "syft.exe",
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
    os_name = _normalize_os(repo_ctx.os.name)
    arch = _normalize_arch(repo_ctx.os.arch)

    if repo_ctx.attr.platform:
        platform = repo_ctx.attr.platform
        if "_" in platform:
            os_name, arch = platform.split("_", 1)
        else:
            fail("rules_sbom: platform '{}' should be in '<os>_<arch>' form".format(platform))
    platform = "{}_{}".format(_normalize_os(os_name), _normalize_arch(arch))

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

    binary_name = artifact.get("binary", "syft")
    if binary_name == "syft":
        build_content = 'exports_files(["syft"], visibility = ["//visibility:public"])\n'
    else:
        build_content = """exports_files(["{binary}"], visibility = ["//visibility:public"])
alias(
    name = "syft",
    actual = "{binary}",
    visibility = ["//visibility:public"],
)
""".format(binary = binary_name)

    repo_ctx.file(
        "BUILD.bazel",
        content = build_content,
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
        "@rules_sbom//toolchains/syft:windows_amd64_toolchain",
    )
