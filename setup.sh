#!/bin/bash

set -e

TOTAL_STEPS=7
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_REPO="${HOME}/develop-env"
DEFAULT_ARCHES=(x86 arm64 riscv)
DEFAULT_KERNEL_KEYS=(2 4 5 6)
DEFAULT_STEPS=(1 2 3 4 5 6 7)
SELECTED_ARCHES=("${DEFAULT_ARCHES[@]}")
SELECTED_KERNEL_KEYS=("${DEFAULT_KERNEL_KEYS[@]}")
SELECTED_STEPS=("${DEFAULT_STEPS[@]}")
STEPS_SPECIFIED=0
SKIP_CHSH=0
FORCE_CHSH=0

if [ ! -d "${ENV_REPO}" ]; then
	ENV_REPO="${SCRIPT_DIR}"
fi

print_usage() {
	cat <<EOF
Usage: ./setup.sh [options]

Options:
  --arch <list>              Restrict cross-compiler related setup to selected arch(es).
                             Supported: x86, arm64, riscv
                             Example: --arch arm64 or --arch x86,arm64
  --kernel <list>            Restrict linux source preparation to selected kernel key(s).
                             Supported: 2,4,5,6
                             Example: --kernel 6 or --kernel 4,6
  --steps <list>             Run selected setup step(s) only.
                             Supported: 1,2,3,4,5,6,7
                             Example: --steps 1,3,7
                             Steps:
                               1 Install apt build dependencies and base developer tools
                               2 Sync develop-env dotfiles/scripts into HOME
                               3 Install vim-plug and sync Vim plugins from .vimrc
                               4 Configure zsh + oh-my-zsh/plugins and optional default shell change
                               5 Prepare Linux workspace and selected kernel source trees
                               6 Install selected Bootlin cross toolchains into LINUX_TOOL_CHAIN
                               7 Generate per-arch toolchain env scripts for ktoolchain
  --set-chsh                 Change default shell to zsh in step 4 (non-interactive).
  --skip-chsh                Skip changing default shell to zsh in step 4.
  -h, --help                 Show this help message and exit.
EOF
}

array_contains() {
	local target="$1"
	shift
	local item
	for item in "$@"; do
		if [ "${item}" = "${target}" ]; then
			return 0
		fi
	done
	return 1
}

add_arches_from_arg() {
	local raw="$1"
	local arch
	local normalized
	local raw_arches
	IFS=',' read -r -a raw_arches <<<"${raw}"
	for arch in "${raw_arches[@]}"; do
		normalized="$(echo "${arch}" | tr -d '[:space:]')"
		case "${normalized}" in
			x86|arm64|riscv) ;;
			*)
				echo "Unsupported arch: ${normalized}. Supported: x86, arm64, riscv"
				exit 1
				;;
		esac
		if ! array_contains "${normalized}" "${SELECTED_ARCHES[@]}"; then
			SELECTED_ARCHES+=("${normalized}")
		fi
	done
}

add_kernels_from_arg() {
	local raw="$1"
	local key
	local normalized
	local raw_keys
	IFS=',' read -r -a raw_keys <<<"${raw}"
	for key in "${raw_keys[@]}"; do
		normalized="$(echo "${key}" | tr -d '[:space:]')"
		case "${normalized}" in
			2|4|5|6) ;;
			*)
				echo "Unsupported kernel key: ${normalized}. Supported: 2, 4, 5, 6"
				exit 1
				;;
		esac
		if ! array_contains "${normalized}" "${SELECTED_KERNEL_KEYS[@]}"; then
			SELECTED_KERNEL_KEYS+=("${normalized}")
		fi
	done
}

add_steps_from_arg() {
	local raw="$1"
	local step
	local normalized
	local raw_steps
	IFS=',' read -r -a raw_steps <<<"${raw}"
	for step in "${raw_steps[@]}"; do
		normalized="$(echo "${step}" | tr -d '[:space:]')"
		case "${normalized}" in
			1|2|3|4|5|6|7) ;;
			*)
				echo "Unsupported step: ${normalized}. Supported: 1, 2, 3, 4, 5, 6, 7"
				exit 1
				;;
		esac
		if ! array_contains "${normalized}" "${SELECTED_STEPS[@]}"; then
			SELECTED_STEPS+=("${normalized}")
		fi
	done
}

parse_args() {
	local explicit_arch=0
	local explicit_kernel=0

	while [ "$#" -gt 0 ]; do
		case "$1" in
			--arch)
				if [ -z "$2" ]; then
					echo "Error: --arch requires a value."
					exit 1
				fi
				if [ "${explicit_arch}" -eq 0 ]; then
					SELECTED_ARCHES=()
					explicit_arch=1
				fi
				add_arches_from_arg "$2"
				shift 2
				;;
			--kernel)
				if [ -z "$2" ]; then
					echo "Error: --kernel requires a value."
					exit 1
				fi
				if [ "${explicit_kernel}" -eq 0 ]; then
					SELECTED_KERNEL_KEYS=()
					explicit_kernel=1
				fi
				add_kernels_from_arg "$2"
				shift 2
				;;
			--steps)
				if [ -z "$2" ]; then
					echo "Error: --steps requires a value."
					exit 1
				fi
				if [ "${STEPS_SPECIFIED}" -eq 0 ]; then
					SELECTED_STEPS=()
					STEPS_SPECIFIED=1
				fi
				add_steps_from_arg "$2"
				shift 2
				;;
			--set-chsh)
				FORCE_CHSH=1
				shift
				;;
			--skip-chsh)
				SKIP_CHSH=1
				shift
				;;
			-h|--help)
				print_usage
				exit 0
				;;
			*)
				echo "Unknown argument: $1"
				print_usage
				exit 1
				;;
		esac
	done

	if [ "${#SELECTED_ARCHES[@]}" -eq 0 ]; then
		echo "Error: at least one arch must be selected."
		exit 1
	fi
	if [ "${#SELECTED_KERNEL_KEYS[@]}" -eq 0 ]; then
		echo "Error: at least one kernel key must be selected."
		exit 1
	fi
	if [ "${#SELECTED_STEPS[@]}" -eq 0 ]; then
		echo "Error: at least one setup step must be selected."
		exit 1
	fi
	if [ "${SKIP_CHSH}" -eq 1 ] && [ "${FORCE_CHSH}" -eq 1 ]; then
		echo "Error: --set-chsh and --skip-chsh cannot be used together."
		exit 1
	fi
}

step_enabled() {
	local target="$1"
	array_contains "${target}" "${SELECTED_STEPS[@]}"
}

run_step() {
	local num="$1"
	local title="$2"
	local func_name="$3"

	if step_enabled "${num}"; then
		echo "Running step ${num}: ${title}"
		"${func_name}"
	else
		echo "Skipping step ${num}: ${title} (not selected)"
	fi
}

require_env_vars() {
	local missing=0
	local var_name
	for var_name in "$@"; do
		if [ -z "${!var_name}" ]; then
			echo "Missing environment variable: ${var_name}"
			missing=1
		fi
	done

	if [ "${missing}" -ne 0 ]; then
		echo "Please export required variables first (usually from ~/.bashrc) and rerun this step."
		return 1
	fi
}

find_helper_script() {
	local name="$1"
	if command -v "${name}" >/dev/null 2>&1; then
		command -v "${name}"
		return 0
	fi
	if [ -x "${HOME}/scripts/${name}" ]; then
		echo "${HOME}/scripts/${name}"
		return 0
	fi
	if [ -x "${SCRIPT_DIR}/scripts/${name}" ]; then
		echo "${SCRIPT_DIR}/scripts/${name}"
		return 0
	fi
	return 1
}

step1_install_sdks() {
	sudo apt update
	sudo apt install -y \
		build-essential libncurses-dev bison flex \
		libssl-dev libelf-dev bc git fakeroot \
		libudev-dev libpci-dev libiberty-dev \
		openssl dwarves zstd libdw-dev libunwind-dev \
		binutils-dev cpio libslang2-dev udev \
		cscope trash-cli universal-ctags cmake
}

step2_sync_env_files() {
	local target_repo="${HOME}/develop-env"

	if [ ! -d "${target_repo}" ]; then
		echo "Cloning develop environment repository to ${target_repo}"
		git clone git@github.com:kyle-liu007/develop-env.git "${target_repo}"
	fi

	ENV_REPO="${target_repo}"
	cp "${ENV_REPO}/.gitconfig" "${HOME}/"
	cp -ar "${ENV_REPO}/scripts" "${HOME}/"
}

step3_configure_vim() {
	cp "${ENV_REPO}/.vimrc" "${HOME}/"
	if ! command -v vim >/dev/null 2>&1; then
		echo "Error: Vim not found. Install Vim first."
		return 1
	fi
	if [ ! -f "${HOME}/.vim/autoload/plug.vim" ]; then
		echo "Installing vim-plug..."
		curl -fLo "${HOME}/.vim/autoload/plug.vim" --create-dirs \
			https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	fi
	echo "Installing plugins via vim-plug..."
	vim -Nu ~/.vimrc -n -e "+PlugInstall --sync" +qa
}

step4_configure_zsh() {
	local zsh_bin
	local session_parent_shell
	local session_parent_shell_name

	cp "${ENV_REPO}/.bashrc" "${HOME}/"
	if ! command -v zsh >/dev/null 2>&1; then
		echo "zsh not found."
		if sudo -n true 2>/dev/null; then
			echo "Installing zsh..."
			sudo -n apt-get install -y zsh
		else
			echo "Warning: no sudo privilege, cannot install zsh automatically."
			echo "Please ask admin to install zsh, then rerun this step."
			return 0
		fi
	fi
	zsh_bin="$(command -v zsh)"

	if [ ! -d "${HOME}/.oh-my-zsh" ]; then
		echo "Installing oh-my-zsh..."
		RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
			"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi

	if [ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
		git clone https://github.com/zsh-users/zsh-autosuggestions \
			"${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
	fi
	if [ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
		git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
			"${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
	fi

	session_parent_shell="$(ps -p "${PPID}" -o comm= 2>/dev/null | tr -d '[:space:]')"
	session_parent_shell_name="${session_parent_shell##*/}"

	if [ "${session_parent_shell_name}" = "zsh" ]; then
		echo "Current session shell is zsh, skipping default shell change."
	elif [ "${SKIP_CHSH}" -eq 1 ]; then
		echo "Skipping default shell change because --skip-chsh is set."
	elif [ "${FORCE_CHSH}" -eq 1 ]; then
		echo "Setting zsh as default shell (--set-chsh enabled)"
		if sudo -n true 2>/dev/null; then
			if sudo -n chsh -s "${zsh_bin}" "${USER}"; then
				echo "Default shell updated to ${zsh_bin}"
			else
				echo "Warning: failed to change default shell automatically."
			fi
		else
			echo "Warning: skipping default shell change because sudo privilege is unavailable."
			echo "Run manually when needed: sudo chsh -s ${zsh_bin} ${USER}"
		fi
	else
		echo "Skipping default shell change by default."
		echo "Use --set-chsh to enable automatic chsh."
	fi

	cp "${ENV_REPO}/.zshrc" "${HOME}/"
	cp "${ENV_REPO}/.oh-my-zsh/custom/"* "${HOME}/.oh-my-zsh/custom/"
	echo "Zsh configuration is updated. Reopen terminal or run: source ~/.zshrc"
}

step5_build_linux_tree() {
	local get_linux_version
	get_linux_version="$(find_helper_script get_linux_version.sh)"
	require_env_vars LINUX_ROOT LINUX_SOURCE LINUX_VSCODE

	cp -ar "${ENV_REPO}/linux/"* "${LINUX_ROOT}"
	mkdir -p "${LINUX_SOURCE}"

	build_linux_source() {
		local kernel_key="$1"
		local linux_version
		local archive
		local path
		linux_version="$(${get_linux_version} "${kernel_key}")"
		archive="linux-${linux_version}.tar.gz"
		path="${LINUX_SOURCE}/linux-${linux_version}"
		if [ ! -d "${path}" ]; then
			mkdir -p "${path}"
			pushd "${LINUX_SOURCE}" >/dev/null
			if [ ! -f "${archive}" ]; then
				wget "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/snapshot/${archive}"
			fi
			tar -xf "${archive}" -C "${path}" --strip-components=1
			popd >/dev/null
		fi
	}

	local kernel_key
	for kernel_key in "${SELECTED_KERNEL_KEYS[@]}"; do
		build_linux_source "${kernel_key}"
	done

	mkdir -p "${LINUX_VSCODE}"
	mkdir -p "${LINUX_ROOT}/linux-qemu"
}

step6_install_cross_compiler() {
	require_env_vars LINUX_TOOL_CHAIN

	build_tool_chain() {
		local arch="$1"
		local sub_arch="$2"
		local archive="${sub_arch}--glibc--stable-2025.08-1.tar.xz"
		if [ ! -d "${LINUX_TOOL_CHAIN}/${arch}/bin" ]; then
			mkdir -p "${LINUX_TOOL_CHAIN}/${arch}"
			pushd "${LINUX_TOOL_CHAIN}/${arch}" >/dev/null
			if [ ! -f "${archive}" ]; then
				wget "https://toolchains.bootlin.com/downloads/releases/toolchains/${sub_arch}/tarballs/${archive}"
			fi
			tar -xf "${archive}" --strip-components=1
			popd >/dev/null
		fi
	}

	local arch
	local sub_arch
	for arch in "${SELECTED_ARCHES[@]}"; do
		case "${arch}" in
			arm64) sub_arch="aarch64" ;;
			riscv) sub_arch="riscv64-lp64d" ;;
			x86) sub_arch="x86-64" ;;
			*)
				echo "Error: unsupported arch ${arch}"
				return 1
				;;
		esac
		build_tool_chain "${arch}" "${sub_arch}"
	done
}

step7_generate_cross_compiler_env() {
	local get_cross_compiler
	local env_dir
	local ktoolchain_script
	local suggested_arch

	if ! get_cross_compiler="$(find_helper_script get_cross_compiler.sh)"; then
		echo "Error: get_cross_compiler.sh not found."
		return 1
	fi
	require_env_vars LINUX_TOOL_CHAIN

	env_dir="${LINUX_TOOL_CHAIN}/env"
	mkdir -p "${env_dir}"

	generate_arch_env() {
		local arch="$1"
		local cross_prefix
		local tc_target
		local env_file
		cross_prefix="$(${get_cross_compiler} "${arch}")"
		tc_target="${cross_prefix%-}"
		env_file="${env_dir}/${arch}.env"

		cat > "${env_file}" <<EOF
export ARCH="$( [ "${arch}" = "x86" ] && echo "x86_64" || echo "${arch}" )"
export CROSS_COMPILE="${cross_prefix}"
export TC_TARGET="${tc_target}"
export KTOOLCHAIN_ACTIVE_ARCH="${arch}"
export KTOOLCHAIN_ACTIVE_BIN="\${LINUX_TOOL_CHAIN}/${arch}/bin"

case ":\${PATH}:" in
	*":\${KTOOLCHAIN_ACTIVE_BIN}:"*) ;;
	*) export PATH="\${KTOOLCHAIN_ACTIVE_BIN}:\${PATH}" ;;
esac
EOF
	}

	local arch
	for arch in "${SELECTED_ARCHES[@]}"; do
		generate_arch_env "${arch}"
	done

	ktoolchain_script="${HOME}/scripts/ktoolchain.sh"
	if [ ! -f "${ktoolchain_script}" ] && [ -f "${SCRIPT_DIR}/scripts/ktoolchain.sh" ]; then
		ktoolchain_script="${SCRIPT_DIR}/scripts/ktoolchain.sh"
	fi

	echo "Generated cross-toolchain env files under ${env_dir}:"
	for arch in "${SELECTED_ARCHES[@]}"; do
		echo "  - ${arch}.env"
	done
	echo "Switch toolchain in current shell with:"
	echo "  source ${ktoolchain_script}"
	suggested_arch="${SELECTED_ARCHES[0]}"
	echo "  ktoolchain use ${suggested_arch}"
}

parse_args "$@"

if [ "${STEPS_SPECIFIED}" -eq 0 ]; then
	print_usage
	exit 0
fi

echo "Non-interactive setup started."
echo "Selected arch(es): ${SELECTED_ARCHES[*]}"
echo "Selected kernel key(s): ${SELECTED_KERNEL_KEYS[*]}"
echo "Selected step(s): ${SELECTED_STEPS[*]}"
if [ "${FORCE_CHSH}" -eq 1 ]; then
	echo "Option enabled: set default shell to zsh"
fi
if [ "${SKIP_CHSH}" -eq 1 ]; then
	echo "Option enabled: skip default shell change"
fi

run_step 1 "Install apt build dependencies and base developer tools" step1_install_sdks
run_step 2 "Sync develop-env dotfiles/scripts into HOME" step2_sync_env_files
run_step 3 "Install vim-plug and sync Vim plugins from .vimrc" step3_configure_vim
run_step 4 "Configure zsh + oh-my-zsh/plugins and optionally set default shell" step4_configure_zsh
run_step 5 "Prepare Linux workspace and selected kernel source trees" step5_build_linux_tree
run_step 6 "Install selected Bootlin cross toolchains into LINUX_TOOL_CHAIN" step6_install_cross_compiler
run_step 7 "Generate per-arch toolchain env scripts for ktoolchain" step7_generate_cross_compiler_env

echo "Setup finished."
