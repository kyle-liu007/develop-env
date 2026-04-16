#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: ${BASH_SOURCE[0]} <linux version> [arch]"
    exit 1
fi

find_helper_script() {
    local name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if command -v "${name}" >/dev/null 2>&1; then
        command -v "${name}"
        return 0
    fi
    if [ -x "${HOME}/scripts/${name}" ]; then
        echo "${HOME}/scripts/${name}"
        return 0
    fi
    if [ -x "${script_dir}/../scripts/${name}" ]; then
        echo "${script_dir}/../scripts/${name}"
        return 0
    fi
    return 1
}

linux_version="$1"
arch="${ARCH:-$2}"
if [ -z "${arch}" ]; then
    echo "Error: arch is empty. Set ARCH or pass [arch] argument."
    exit 1
fi
cross_compile="${CROSS_COMPILE}"

if [ -z "${cross_compile}" ]; then
    if ! get_cross_compiler="$(find_helper_script get_cross_compiler.sh)"; then
        echo "Error: get_cross_compiler.sh not found."
        exit 1
    fi
    cross_compile="$("${get_cross_compiler}" "${arch}")"
fi

if [ -n "${LINUX_TOOL_CHAIN}" ] && [ -d "${LINUX_TOOL_CHAIN}/${arch}/bin" ]; then
    case ":${PATH}:" in
        *":${LINUX_TOOL_CHAIN}/${arch}/bin:"*) ;;
        *) export PATH="${LINUX_TOOL_CHAIN}/${arch}/bin:${PATH}" ;;
    esac
fi

export ARCH="${arch}"
export CROSS_COMPILE="${cross_compile}"
linux_source="${LINUX_SOURCE}/linux-${linux_version}"
output="${LINUX_BUILD}/linux-${linux_version}/${arch}"

# rm -r ${linux_source}/include/generated/
# rm -r ${linux_source}/include/config/
# rm -r ${linux_source}/arch/${arch}/include/generated/

pushd "${linux_source}" >/dev/null
make ARCH="${arch}" CROSS_COMPILE="${cross_compile}" clean O="${output}"
popd >/dev/null
