#!/bin/bash

set -euo pipefail

script_path() {
    if [ -n "${BASH_VERSION:-}" ] && [ -n "${BASH_SOURCE[0]:-}" ]; then
        printf '%s\n' "${BASH_SOURCE[0]}"
        return
    fi
    printf '%s\n' "$0"
}

find_helper_script() {
    local name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "$(script_path)")" && pwd)"

    if [ -x "${script_dir}/${name}" ]; then
        echo "${script_dir}/${name}"
        return 0
    fi
    if command -v "${name}" >/dev/null 2>&1; then
        command -v "${name}"
        return 0
    fi
    if [ -x "${HOME}/scripts/${name}" ]; then
        echo "${HOME}/scripts/${name}"
        return 0
    fi
    return 1
}

write_clangd_config() {
    local clangd_file="$1"
    local compile_db="$2"

    cat > "${clangd_file}" <<EOF
CompileFlags:
  CompilationDatabase: ${compile_db}
Index:
  Background: Build
EOF
}

build_compile_db() {
    local root_dir="$1"
    shift 1

    (
        python3 "${generate_compdb}" -d "${root_dir}" "$@"
    )
}

merge_compile_db() {
    local output_db="$1"
    local first_db="$2"
    local second_db="$3"

    python3 - "$output_db" "$first_db" "$second_db" <<'PY'
import json
import pathlib
import sys

output_path = pathlib.Path(sys.argv[1])
first_path = pathlib.Path(sys.argv[2])
second_path = pathlib.Path(sys.argv[3])

merged = []
for path in (first_path, second_path):
    if not path.exists():
        continue
    with path.open("r", encoding="utf-8") as fp:
        data = json.load(fp)
    if not isinstance(data, list):
        raise SystemExit(f"Error: {path} is not a JSON array")
    merged.extend(data)

with output_path.open("w", encoding="utf-8") as fp:
    json.dump(merged, fp, indent=2)
    fp.write("\n")
PY
}

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $(script_path) <linux_key> <arch> [rebuild]" >&2
    exit 1
fi

if ! get_linux_version="$(find_helper_script get_linux_version.sh)"; then
    echo "Error: get_linux_version.sh not found." >&2
    exit 1
fi
if ! generate_compdb="$(find_helper_script generate_compdb.py)"; then
    echo "Error: generate_compdb.py not found." >&2
    exit 1
fi
if ! command -v clangd >/dev/null 2>&1; then
    echo "Error: clangd not found in PATH." >&2
    exit 1
fi

linux_key="$1"
arch="$2"
mode="${3:-}"

linux_version="$("${get_linux_version}" "${linux_key}")"

working_dir="$(pwd)"
linux_source="${LINUX_SOURCE}/linux-${linux_version}"
linux_output="${LINUX_BUILD}/linux-${linux_version}/${arch}"
module_compile_db="${working_dir}/compile_commands.json"
kernel_compile_db="${linux_output}/compile_commands.json"
clangd_file=".clangd"

echo "== generate_kernel_clangd =="
echo "linux_key=${linux_key}"
echo "linux_version=${linux_version}"
echo "arch=${arch}"
echo "mode=${mode}"
echo "working_dir=${working_dir}"
echo "linux_source=${linux_source}"
echo "linux_output=${linux_output}"

if [ "${mode}" = "rebuild" ]; then
    pushd "${linux_output}" >/dev/null
    echo "Rebuilding kernel compile_commands.json ..."
    echo "scan_dir=${linux_output}"
    build_compile_db "${linux_output}" "${linux_output}"
    popd >/dev/null
else
    if [ ! -f "${kernel_compile_db}" ]; then
        echo "Warning: kernel compile_commands.json not found: ${kernel_compile_db}" >&2
        echo "Hint: run $(script_path) ${linux_key} ${arch} rebuild to generate it." >&2
    fi
fi

build_compile_db "${linux_output}" "${working_dir}"
merge_compile_db "${module_compile_db}" "${module_compile_db}" "${kernel_compile_db}"

write_clangd_config "${clangd_file}" "${working_dir}"
echo "Updated clangd config: ${clangd_file}"
