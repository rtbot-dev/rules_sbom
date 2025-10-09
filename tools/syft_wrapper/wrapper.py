import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

FORMAT_MAP = {
    "cyclonedx_json": "cyclonedx-json",
    "spdx_json": "spdx-json",
}


def _read_manifest(manifest_path: Path):
    entries = []
    inputs = []
    if not manifest_path:
        return entries, inputs
    if not manifest_path.exists():
        return entries, inputs

    with manifest_path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if "\t" in line:
                src, rel = line.split("\t", 1)
            else:
                src = rel = line
            entries.append((Path(src), Path(rel)))
            inputs.append(rel)
    return entries, inputs


def _copy_inputs(entries):
    tmpdir = Path(tempfile.mkdtemp(prefix="rules_sbom_"))
    for src, rel in entries:
        try:
            dest = tmpdir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
        except FileNotFoundError:
            # Skip missing files; Syft will handle absent inputs.
            continue
    return tmpdir


def _run_syft(tool, syft_format, staging_dir, output, config, extra_args):
    cmd = [tool, "scan", str(staging_dir), "-o", f"{syft_format}={output}", "--quiet"]
    if config:
        cmd.extend(["--config", config])
    if extra_args:
        cmd.extend(extra_args)
    env = os.environ.copy()
    try:
        subprocess.run(cmd, check=True, env=env)
        return True
    except subprocess.CalledProcessError as exc:
        print(f"syft_wrapper: syft invocation failed ({exc.returncode})", file=sys.stderr)
        return False
    except OSError as exc:
        print(f"syft_wrapper: unable to launch syft: {exc}", file=sys.stderr)
        return False


def _infer_components(entries):
    components = []
    lock = next((e for e in entries if e[1].as_posix().endswith("package-lock.json")), None)
    pkg = next((e for e in entries if e[1].as_posix().endswith("package.json")), None)

    def _load_json(path: Path):
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)

    if lock and lock[0].exists():
        try:
            data = _load_json(lock[0])
            deps = data.get("dependencies", {})
            for name in sorted(deps.keys()):
                info = deps[name] or {}
                version = info.get("version") or info.get("resolved") or ""
                components.append({
                    "name": name,
                    "version": version,
                    "source": lock[1].as_posix(),
                })
        except Exception:
            components = []
    elif pkg and pkg[0].exists():
        try:
            data = _load_json(pkg[0])
            deps = data.get("dependencies", {})
            for name in sorted(deps.keys()):
                components.append({
                    "name": name,
                    "version": deps[name],
                    "source": pkg[1].as_posix(),
                })
        except Exception:
            components = []
    return components


def _write_placeholder(output, fmt, target, config, tool_hint, inputs, components):
    fallback = {
        "tool": "rules_sbom syft wrapper placeholder",
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "format": fmt,
        "target": target,
        "config": config,
        "tool_hint": tool_hint,
        "inputs": inputs,
        "components": components,
    }
    with output.open("w", encoding="utf-8") as fh:
        json.dump(fallback, fh)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--format", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--inputs-manifest", dest="inputs_manifest")
    parser.add_argument("--config")
    parser.add_argument("--tool", required=True)
    parser.add_argument("--extra-args", nargs=argparse.REMAINDER)

    args = parser.parse_args(argv)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    manifest_path = Path(args.inputs_manifest) if args.inputs_manifest else None
    entries, inputs_json = _read_manifest(manifest_path)
    components_json = _infer_components(entries)

    staging_dir = _copy_inputs(entries)
    syft_format = FORMAT_MAP.get(args.format, args.format)

    try:
        success = _run_syft(
            args.tool,
            syft_format,
            staging_dir,
            str(output_path),
            args.config,
            args.extra_args,
        )
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)

    if not success:
        print("syft_wrapper: generating placeholder output", file=sys.stderr)
        _write_placeholder(
            output_path,
            args.format,
            args.target,
            args.config,
            args.tool,
            inputs_json,
            components_json,
        )


if __name__ == "__main__":
    main()
