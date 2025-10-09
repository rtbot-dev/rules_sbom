"""Syft-backed SBOM toolchain definition stubs."""

load("//sbom/internal:providers.bzl", "SbomToolchainInfo")

def _syft_toolchain_impl(ctx):
    tool_file = ctx.file.tool
    wrapper_info = ctx.attr.wrapper[DefaultInfo] if ctx.attr.wrapper else None
    wrapper_runfiles = wrapper_info.files_to_run if wrapper_info else None
    toolchain_info = platform_common.ToolchainInfo(
        sbom = SbomToolchainInfo(
            tool = tool_file,
            default_format = ctx.attr.default_format,
            env = ctx.attr.env,
            supports_formats = ctx.attr.supports_formats,
            wrapper = wrapper_runfiles,
        ),
    )
    return [toolchain_info]

syft_toolchain = rule(
    implementation = _syft_toolchain_impl,
    attrs = {
        "tool": attr.label(
            doc = "Executable binary for Syft.",
            cfg = "exec",
            allow_single_file = True,
            mandatory = True,
        ),
        "default_format": attr.string(
            doc = "Default output format emitted by the wrapped tool.",
            default = "cyclonedx_json",
        ),
        "supports_formats": attr.string_list(
            doc = "List of supported SBOM formats.",
            default = ["cyclonedx_json"],
        ),
        "env": attr.string_dict(
            doc = "Environment overrides applied when running the tool.",
            default = {},
        ),
        "wrapper": attr.label(
            doc = "Optional wrapper executable for preprocessing.",
            cfg = "exec",
            executable = True,
        ),
    },
    doc = "Wraps a Syft CLI executable for use as an SBOM toolchain.",
    provides = [platform_common.ToolchainInfo],
)
