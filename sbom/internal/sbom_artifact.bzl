"""Implementation for the sbom_artifact rule."""

load("//sbom/internal:inputs_manifest.bzl", "build_inputs_manifest")
load("//sbom/internal:providers.bzl", "SbomInfo")

_SUPPORTED_FORMATS = [
    "cyclonedx_json",
    "spdx_json",
]

_TOOLCHAIN_ID = "//toolchains:sbom_toolchain_type"

def _sbom_artifact_impl(ctx):
    toolchain = ctx.toolchains[_TOOLCHAIN_ID].sbom

    requested_format = ctx.attr.format or toolchain.default_format
    supported_formats = toolchain.supports_formats or _SUPPORTED_FORMATS

    if requested_format not in supported_formats:
        fail("Format '{}' is not supported by the configured SBOM toolchain (supports: {})".format(
            requested_format,
            ", ".join(supported_formats),
        ))

    output = ctx.actions.declare_file(ctx.attr.output)

    target_info = ctx.attr.target[DefaultInfo]
    target_files = target_info.files
    default_runfiles = target_info.default_runfiles

    manifest_sets = [target_files]
    if default_runfiles:
        manifest_sets.append(default_runfiles.files)
    manifest_files = depset(transitive = manifest_sets)

    config_file = None
    if ctx.attr.config:
        config_file = ctx.file.config

    inputs_manifest = ctx.actions.declare_file("{}_inputs.list".format(ctx.label.name))
    manifest_content = build_inputs_manifest(manifest_files, config_file)
    ctx.actions.write(
        output = inputs_manifest,
        content = manifest_content,
    )

    args = ctx.actions.args()
    args.add("--output", output.path)
    args.add("--format", requested_format)
    args.add("--target", str(ctx.attr.target.label))
    args.add("--inputs-manifest", inputs_manifest.path)

    if config_file:
        args.add("--config", config_file.path)

    env = dict(toolchain.env or {})

    executable = toolchain.wrapper or toolchain.tool
    extra_tools = []
    if toolchain.wrapper:
        args.add("--tool", toolchain.tool.path)
        extra_tools.append(toolchain.tool)

    transitive_inputs = [target_files]
    if default_runfiles:
        transitive_inputs.append(default_runfiles.files)
    inputs = depset(
        direct = [inputs_manifest] + ([config_file] if config_file else []),
        transitive = transitive_inputs,
    )

    ctx.actions.run(
        executable = executable,
        arguments = [args],
        inputs = inputs,
        tools = extra_tools,
        outputs = [output],
        mnemonic = "GenerateSbom",
        progress_message = "Generating SBOM for {}".format(ctx.attr.target.label),
        env = env,
    )

    return [
        DefaultInfo(files = depset([output])),
        SbomInfo(
            sbom = output,
            format = requested_format,
            target = ctx.attr.target.label,
        ),
    ]

sbom_artifact = rule(
    implementation = _sbom_artifact_impl,
    attrs = {
        "target": attr.label(
            doc = "Label representing the Bazel target to analyze.",
            mandatory = True,
            providers = [DefaultInfo],
        ),
        "format": attr.string(
            doc = "Requested SBOM output format identifier.",
            default = "cyclonedx_json",
            values = _SUPPORTED_FORMATS,
        ),
        "output": attr.string(
            doc = "Filename to use for the generated SBOM artifact.",
            default = "sbom.json",
        ),
        "config": attr.label(
            doc = "Optional configuration file for the underlying SBOM tool.",
            allow_single_file = True,
        ),
    },
    doc = "Generates a Software Bill of Materials (SBOM) for a given target.",
    toolchains = [_TOOLCHAIN_ID],
)
