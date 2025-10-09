#!/usr/bin/env bash

set -euo pipefail

format=""
output=""
target=""
inputs_manifest=""
config=""
tool=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            format="$2"
            shift 2
            ;;
        --output)
            output="$2"
            shift 2
            ;;
        --target)
            target="$2"
            shift 2
            ;;
        --inputs-manifest)
            inputs_manifest="$2"
            shift 2
            ;;
        --config)
            config="$2"
            shift 2
            ;;
        --tool)
            tool="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            shift
            ;;
    esac
done

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
elif command -v py >/dev/null 2>&1; then
    PYTHON_CMD="py -3"
else
    PYTHON_CMD=""
fi

if [[ -z "${output}" ]]; then
    echo "syft_wrapper: --output is required" >&2
    exit 1
fi

mkdir -p "$(dirname "${output}")"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

inputs_json="[]"
if [[ -n "${inputs_manifest}" && -f "${inputs_manifest}" ]]; then
    if [[ -n "${PYTHON_CMD}" ]]; then
        inputs_json="$(
${PYTHON_CMD} - "${inputs_manifest}" <<'PY' 2>/dev/null
import json
import sys

manifest_path = sys.argv[1]
entries = []
try:
    with open(manifest_path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t", 1)
            rel = parts[1] if len(parts) > 1 else parts[0]
            entries.append(rel)
except FileNotFoundError:
    entries = []

print(json.dumps(entries))
PY
        )"
        inputs_json="${inputs_json//$'\n'/}"
        if [[ -z "${inputs_json}" ]]; then
            inputs_json="[]"
        fi
    else
        inputs_json="["
        first_entry=true
        while IFS= read -r line || [[ -n "${line}" ]]; do
            if [[ -z "${line}" ]]; then
                continue
            fi
            rel="${line#*$'\t'}"
            if [[ "${line}" == "${rel}" ]]; then
                rel="${line}"
            fi
            escaped=${rel//\\/\\\\}
            escaped=${escaped//\"/\\\"}
            if [[ "${first_entry}" == true ]]; then
                inputs_json+="\"${escaped}\""
                first_entry=false
            else
                inputs_json+=",\"${escaped}\""
            fi
        done < "${inputs_manifest}"
        inputs_json+="]"
        if [[ "${first_entry}" == true ]]; then
            inputs_json="[]"
        fi
    fi
fi

if [[ -n "${tool}" && -x "${tool}" ]] && [[ -n "${inputs_manifest}" && -f "${inputs_manifest}" ]] && [[ -n "${PYTHON_CMD}" ]]; then
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/rules_sbom.XXXXXX")"
    if ${PYTHON_CMD} - "${inputs_manifest}" "${tmpdir}" <<'PY' 2>/dev/null
import os
import shutil
import sys

manifest_path = sys.argv[1]
destination = sys.argv[2]

with open(manifest_path, "r", encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        src = parts[0]
        rel = parts[1] if len(parts) > 1 else parts[0]
        target_path = os.path.join(destination, rel)
        os.makedirs(os.path.dirname(target_path) or destination, exist_ok=True)
        shutil.copy2(src, target_path)
PY
    then
        syft_format="${format}"
        case "${format}" in
            cyclonedx_json)
                syft_format="cyclonedx-json"
                ;;
            spdx_json)
                syft_format="spdx-json"
                ;;
        esac
        syft_args=("${tool}" "scan" "${tmpdir}" "-o" "${syft_format}=${output}" "--quiet")
        if [[ -n "${config}" ]]; then
            syft_args+=("--config" "${config}")
        fi
        if "${syft_args[@]}"; then
            rm -rf "${tmpdir}"
            exit 0
        else
            echo "syft_wrapper: Syft execution failed, falling back to placeholder output" >&2
        fi
    else
        echo "syft_wrapper: Failed to prepare staging directory, falling back to placeholder output" >&2
    fi
    rm -rf "${tmpdir}"
fi

components_json="[]"
if [[ -n "${inputs_manifest}" && -f "${inputs_manifest}" ]] && [[ -n "${PYTHON_CMD}" ]]; then
    components_json="$(
${PYTHON_CMD} - "${inputs_manifest}" <<'PY' 2>/dev/null
import json
import sys

manifest_path = sys.argv[1]
entries = []
try:
    with open(manifest_path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t", 1)
            src = parts[0]
            rel = parts[1] if len(parts) > 1 else parts[0]
            entries.append((src, rel))
except FileNotFoundError:
    entries = []

component_entries = []
lock_entry = next((e for e in entries if e[1].endswith("package-lock.json")), None)
pkg_entry = next((e for e in entries if e[1].endswith("package.json")), None)

def _load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)

if lock_entry:
    try:
        data = _load_json(lock_entry[0])
        dependencies = data.get("dependencies", {})
        for name in sorted(dependencies.keys()):
            info = dependencies[name] or {}
            version = info.get("version") or info.get("resolved") or ""
            component_entries.append({
                "name": name,
                "version": version,
                "source": lock_entry[1],
            })
    except Exception:
        component_entries = []
elif pkg_entry:
    try:
        data = _load_json(pkg_entry[0])
        dependencies = data.get("dependencies", {})
        for name in sorted(dependencies.keys()):
            component_entries.append({
                "name": name,
                "version": dependencies[name],
                "source": pkg_entry[1],
            })
    except Exception:
        component_entries = []

print(json.dumps(component_entries))
PY
    )"
    components_json="${components_json//$'\n'/}"
    if [[ -z "${components_json}" ]]; then
        components_json="[]"
    fi
fi

cat > "${output}" <<EOF
{
  "tool": "rules_sbom syft wrapper placeholder",
  "timestamp": "${timestamp}",
  "format": "${format}",
  "target": "${target}",
  "config": "${config}",
  "tool_hint": "${tool}",
  "inputs": ${inputs_json},
  "components": ${components_json}
}
EOF
