#!/usr/bin/env python3
"""Append install instructions to a GitHub release body."""

import argparse
import hashlib
import subprocess
import textwrap
import urllib.request
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    tar_url = f"https://github.com/{args.repo}/archive/refs/tags/{args.tag}.tar.gz"
    with urllib.request.urlopen(tar_url) as response:
        tarball = response.read()
    sha256 = hashlib.sha256(tarball).hexdigest()

    existing = subprocess.check_output(
        ["gh", "release", "view", args.tag, "--json", "body", "--jq", ".body"],
        text=True,
    ).strip()

    body_parts = [
        "## Install with Bzlmod",
        "",
        "Add to your `MODULE.bazel`:",
        "",
        "```starlark",
        f"bazel_dep(name = \"rules_sbom\", version = \"{args.version}\")",
        "",
        "sbom_ext = use_extension(\"@rules_sbom//sbom:extensions.bzl\", \"sbom_setup\")",
        "```",
        "",
        "## Install with a WORKSPACE",
        "",
        "Download and pin the release archive:",
        "",
        f"- URL: `{tar_url}`",
        f"- SHA256: `{sha256}`",
        "",
        "Then in your `WORKSPACE` file:",
        "",
        "```starlark",
        "load(\"@bazel_tools//tools/build_defs/repo:http.bzl\", \"http_archive\")",
        "",
        "http_archive(",
        "    name = \"rules_sbom\",",
        f"    urls = [\"{tar_url}\"],",
        f"    strip_prefix = \"rules_sbom-{args.version}\",",
        f"    sha256 = \"{sha256}\",",
        ")",
        "",
        "load(\"@rules_sbom//sbom:repositories.bzl\", \"syft_repository\")",
        "load(\"@rules_sbom//sbom:setup.bzl\", \"rules_sbom_setup\")",
        "",
        "rules_sbom_setup(syft_repository)",
        "```",
        "",
        f"See [docs/overview.md](https://github.com/{args.repo}/blob/{args.tag}/docs/overview.md) for advanced configuration options.",
        "",
        "---",
        "",
        existing,
    ]
    body = "\n".join(body_parts)

    Path("release-body.md").write_text(body, encoding="utf-8")


if __name__ == "__main__":
    main()
