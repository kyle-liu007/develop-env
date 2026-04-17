#!/bin/bash
# ===========================================================
# Should be sourced to persist exported env variables.
# ===========================================================

script_path() {
	if [ -n "${BASH_VERSION:-}" ] && [ -n "${BASH_SOURCE[0]:-}" ]; then
		printf '%s\n' "${BASH_SOURCE[0]}"
		return
	fi

	if [ -n "${ZSH_VERSION:-}" ]; then
		# In zsh, %x expands to current script path.
		eval 'printf "%s\n" "${(%):-%x}"'
		return
	fi

	printf '%s\n' "$0"
}

is_sourced() {
	if [ -n "${ZSH_VERSION:-}" ]; then
		case "${ZSH_EVAL_CONTEXT:-}" in
			*:file*) return 0 ;;
		esac
		return 1
	fi

	if [ -n "${BASH_VERSION:-}" ]; then
		[ "${BASH_SOURCE[0]}" != "$0" ]
		return
	fi

	return 1
}

finish() {
	local code="$1"
	if is_sourced; then
		return "${code}"
	fi
	exit "${code}"
}

require_env_vars() {
	local missing=0
	local var_name
	local var_value
	for var_name in "$@"; do
		eval "var_value=\${${var_name}:-}"
		if [ -z "${var_value}" ]; then
			echo "Missing environment variable: ${var_name}" >&2
			missing=1
		fi
	done
	return "${missing}"
}

if [ $# -lt 2 ]; then
	echo "Usage: $(script_path) <linux version key> <arch> [rebuild]" >&2
	finish 1
fi

if ! require_env_vars LINUX_ROOT LINUX_SOURCE LINUX_BUILD LINUX_TOOL_CHAIN; then
	echo "Please export required environment variables first." >&2
	finish 1
fi

if ! declare -F ktoolchain >/dev/null 2>&1; then
	echo "Error: ktoolchain not found in current shell." >&2
	echo "Run: source ~/scripts/ktoolchain.sh" >&2
	finish 1
fi

if ! get_linux_version="$(command -v get_linux_version.sh)"; then
	get_linux_version="$(cd "$(dirname "$(script_path)")" && pwd)/get_linux_version.sh"
fi
if ! unset_module_build_env="$(command -v unset_module_build_env.sh)"; then
	unset_module_build_env="$(cd "$(dirname "$(script_path)")" && pwd)/unset_module_build_env.sh"
fi
if [ ! -x "${get_linux_version}" ]; then
	echo "Error: get_linux_version.sh not found." >&2
	finish 1
fi
if [ ! -x "${unset_module_build_env}" ]; then
	echo "Error: unset_module_build_env.sh not found." >&2
	finish 1
fi

linux_version="$("${get_linux_version}" "$1")"
arch="$2"
linux_output="${LINUX_BUILD}/linux-${linux_version}/${arch}"

build_kernel() {
	# shellcheck disable=SC1090
	source "${unset_module_build_env}"
	echo "******* start building linux kernel *******"
	pushd "${LINUX_ROOT}" >/dev/null
	./build.sh "${linux_version}" "${arch}"
	popd >/dev/null
}

if [ -n "$3" ]; then
	build_kernel
fi

if ! ktoolchain use "${arch}"; then
	finish 1
fi

export KERNELDIR="${linux_output}/source"
export SYSOUT="${linux_output}"

# Prepare module build headers for modules do not support cross-compilation.
#kernel_modlib="/lib/modules/$(uname -r)"
#sudo mv "${kernel_modlib}/build" ""${kernel_modlib}/build.bak"
#sudo mv "${kernel_modlib}/source" ""${kernel_modlib}/source.bak"
#sudo ln -sfT "${linux_output}" "${kernel_modlib}/build"
#sudo ln -sfT "${linux_output}/source" "${kernel_modlib}/source"