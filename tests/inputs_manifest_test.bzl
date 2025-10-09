"""Unit tests for the inputs manifest helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//sbom/internal:inputs_manifest.bzl", "build_inputs_manifest")

def _empty_manifest_test(ctx):
    env = unittest.begin(ctx)

    result = build_inputs_manifest(depset(), None)
    asserts.equals(env, "", result)

    return unittest.end(env)

def _sorted_manifest_test(ctx):
    env = unittest.begin(ctx)

    fake_files = [
        _fake_file("/execroot/workspace/b/path.txt", "b/path.txt"),
        _fake_file("/execroot/workspace/a/config.json", "a/config.json"),
    ]

    result = build_inputs_manifest(
        files = depset(fake_files),
        config_file = None,
    )

    expected = "/execroot/workspace/a/config.json\ta/config.json\n/execroot/workspace/b/path.txt\tb/path.txt\n"
    asserts.equals(env, expected, result)

    return unittest.end(env)

def _include_config_test(ctx):
    env = unittest.begin(ctx)

    fake_files = [
        _fake_file("/root/lib/data.txt", "lib/data.txt"),
    ]
    config_file = _fake_file("/root/cfg/tool.yaml", "cfg/tool.yaml")

    result = build_inputs_manifest(
        files = depset(fake_files),
        config_file = config_file,
    )

    expected = "/root/cfg/tool.yaml\tcfg/tool.yaml\n/root/lib/data.txt\tlib/data.txt\n"
    asserts.equals(env, expected, result)

    return unittest.end(env)

def _fake_file(path, short_path):
    return struct(path = path, short_path = short_path)

empty_manifest_test = unittest.make(_empty_manifest_test)
sorted_manifest_test = unittest.make(_sorted_manifest_test)
include_config_test = unittest.make(_include_config_test)

def inputs_manifest_test_suite():
    return unittest.suite(
        "inputs_manifest",
        empty_manifest_test,
        sorted_manifest_test,
        include_config_test,
    )
