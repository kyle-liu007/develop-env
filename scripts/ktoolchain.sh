#!/bin/bash

_ktoolchain_script_path() {
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

_ktoolchain_usage() {
	echo "Usage:"
	echo "  ktoolchain use x86|arm64|riscv"
	echo "  ktoolchain current"
	echo "  ktoolchain off"
}

_ktoolchain_env_file() {
	local arch="$1"

	if [ -z "${LINUX_TOOL_CHAIN}" ]; then
		echo "Error: LINUX_TOOL_CHAIN is not set." >&2
		return 1
	fi

	echo "${LINUX_TOOL_CHAIN}/env/${arch}.env"
}

_ktoolchain_is_sourced() {
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

_ktoolchain_restore_path() {
	if [ -n "${KTOOLCHAIN_ORIGINAL_PATH}" ]; then
		export PATH="${KTOOLCHAIN_ORIGINAL_PATH}"
	fi
}

_ktoolchain_set_tool_vars() {
	if [ -z "${CROSS_COMPILE}" ]; then
		return 0
	fi

	export CC="${CROSS_COMPILE}gcc"
	export CXX="${CROSS_COMPILE}g++"
	export CPP="${CROSS_COMPILE}cpp"
	export AS="${CROSS_COMPILE}as"
	export LD="${CROSS_COMPILE}ld"
	export AR="${CROSS_COMPILE}ar"
	export NM="${CROSS_COMPILE}nm"
	export STRIP="${CROSS_COMPILE}strip"
	export OBJCOPY="${CROSS_COMPILE}objcopy"
	export OBJDUMP="${CROSS_COMPILE}objdump"
	export RANLIB="${CROSS_COMPILE}ranlib"
	export READELF="${CROSS_COMPILE}readelf"
}

_ktoolchain_unset_tool_vars() {
	unset CC CXX CPP AS LD AR NM STRIP OBJCOPY OBJDUMP RANLIB READELF
}

_ktoolchain_show_current() {
	echo "ARCH=${ARCH:-<unset>}"
	echo "CROSS_COMPILE=${CROSS_COMPILE:-<unset>}"
	echo "TC_TARGET=${TC_TARGET:-<unset>}"
	echo "gcc=$(command -v gcc || echo '<not found>')"
	if [ -n "${CROSS_COMPILE}" ]; then
		echo "${CROSS_COMPILE}gcc=$(command -v "${CROSS_COMPILE}gcc" || echo '<not found>')"
	fi
	echo "CC=${CC:-<unset>}"
	if [ -n "${CC}" ]; then
		echo "CC_path=$(command -v "${CC}" || echo '<not found>')"
	fi
}

_ktoolchain_use() {
	local arch="$1"
	local env_file

	case "${arch}" in
		x86|arm64|riscv) ;;
		*)
			echo "Error: unsupported arch '${arch}'." >&2
			_ktoolchain_usage
			return 1
			;;
	esac

	env_file="$(_ktoolchain_env_file "${arch}")" || return 1
	if [ ! -f "${env_file}" ]; then
		echo "Error: missing env file ${env_file}." >&2
		echo "Run setup step 7 first to generate toolchain env files." >&2
		return 1
	fi

	if [ -z "${KTOOLCHAIN_ORIGINAL_PATH}" ]; then
		export KTOOLCHAIN_ORIGINAL_PATH="${PATH}"
	fi
	_ktoolchain_restore_path
	unset ARCH CROSS_COMPILE TC_TARGET KTOOLCHAIN_ACTIVE_ARCH KTOOLCHAIN_ACTIVE_BIN
	_ktoolchain_unset_tool_vars

	# shellcheck disable=SC1090
	source "${env_file}"
	_ktoolchain_set_tool_vars
	echo "Switched cross toolchain to ${arch}."
	_ktoolchain_show_current
}

_ktoolchain_off() {
	_ktoolchain_restore_path
	unset KTOOLCHAIN_ORIGINAL_PATH
	unset ARCH CROSS_COMPILE TC_TARGET KTOOLCHAIN_ACTIVE_ARCH KTOOLCHAIN_ACTIVE_BIN
	_ktoolchain_unset_tool_vars
	echo "Cross toolchain is disabled for current shell."
	_ktoolchain_show_current
}

ktoolchain() {
	local action="$1"

	case "${action}" in
		use)
			shift
			if [ $# -ne 1 ]; then
				_ktoolchain_usage
				return 1
			fi
			_ktoolchain_use "$1"
			;;
		current)
			_ktoolchain_show_current
			;;
		off)
			_ktoolchain_off
			;;
		*)
			_ktoolchain_usage
			return 1
			;;
	esac
}

if ! _ktoolchain_is_sourced; then
	if [ "$1" = "use" ] || [ "$1" = "off" ]; then
		echo "Error: '${1}' must run in current shell. Use source first." >&2
		echo "Example: source $(_ktoolchain_script_path) && ktoolchain ${1} ${2}" >&2
		exit 1
	fi
	ktoolchain "$@"
fi
