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
        dest = tmpdir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            if src.exists() and src.is_dir():
                shutil.copytree(src, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dest)
        except IsADirectoryError:
            shutil.copytree(src, dest, dirs_exist_ok=True)
        except FileNotFoundError:
            # Skip missing files; Syft will handle absent inputs.
            continue
    return tmpdir


def _read_package_json(pkg_dir: Path):
    pkg_json = pkg_dir / "package.json"
    if not pkg_json.exists():
        return None
    try:
        return json.loads(pkg_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def _collect_node_modules(root: Path):
    node_modules = root / "node_modules"
    if not node_modules.exists():
        return {}

    packages = {}
    for pkg_json in node_modules.rglob("package.json"):
        pkg_dir = pkg_json.parent
        rel = pkg_dir.relative_to(root)
        data = _read_package_json(pkg_dir)
        if not data:
            continue
        name = data.get("name")
        if not name or name.count("/") > 1:
            continue
        dependencies = {
            dep_name: dep_spec
            for dep_name, dep_spec in (data.get("dependencies") or {}).items()
            if dep_name and dep_name.count("/") <= 1
        }
        packages[rel.as_posix()] = {
            "name": name,
            "version": data.get("version"),
            "dependencies": dependencies,
        }
    return packages


def _write_root_package_manifest(root: Path, packages: dict):
    node_modules = root / "node_modules"
    if not node_modules.exists():
        return

    dependencies = {}

    def _add_dependency(pkg_path: Path, display_name: str):
        data = _read_package_json(pkg_path)
        if not data:
            return
        version = data.get("version")
        if version and display_name.count("/") <= 1:
            dependencies[display_name] = version

    for child in node_modules.iterdir():
        if child.name.startswith("."):
            continue
        if child.is_dir():
            if child.name.startswith("@"):
                for scoped in child.iterdir():
                    if scoped.is_dir():
                        scoped_name = "{}/{}".format(child.name, scoped.name)
                        _add_dependency(scoped, scoped_name)
            else:
                _add_dependency(child, child.name)

    package_json = {
        "name": "sbom-staging",
        "version": "0.0.0",
        "dependencies": dependencies,
    }
    (root / "package.json").write_text(json.dumps(package_json, indent=2), encoding="utf-8")

    packages_section = {
        "": {
            "name": package_json["name"],
            "version": package_json["version"],
            "dependencies": {
                dep: spec for dep, spec in dependencies.items() if dep.count("/") <= 1
            },
        },
    }

    for rel, meta in packages.items():
        entry = {}
        if meta.get("version"):
            entry["version"] = meta["version"]
        if meta.get("dependencies"):
            entry["dependencies"] = meta["dependencies"]
        packages_section[rel] = entry

    lock = {
        "name": package_json["name"],
        "version": package_json["version"],
        "lockfileVersion": 3,
        "packages": packages_section,
    }
    (root / "package-lock.json").write_text(json.dumps(lock, indent=2), encoding="utf-8")


def _run_syft(tool, syft_format, staging_dir, output, config, extra_args):
    cmd = [tool, "scan", str(staging_dir), "-o", f"{syft_format}={output}", "--quiet"]
    cmd.extend([
        "--select-catalogers",
        "-github-actions-usage-cataloger,-github-action-workflow-usage-cataloger",
    ])
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

    packages = _collect_node_modules(staging_dir)
    if packages:
        _write_root_package_manifest(staging_dir, packages)

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
