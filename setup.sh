#!/bin/bash

set -e

TOTAL_STEPS=7
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_REPO="${HOME}/develop-env"

if [ ! -d "${ENV_REPO}" ]; then
	ENV_REPO="${SCRIPT_DIR}"
fi

ask_yes_no() {
	local prompt="$1"
	local answer
	while true; do
		read -r -p "${prompt} [Y/n]: " answer
		case "${answer}" in
			""|"y"|"Y"|"yes"|"YES"|"Yes")
				return 0
				;;
			"n"|"N"|"no"|"NO"|"No")
				return 1
				;;
			*)
				echo "Please input y or n."
				;;
		esac
	done
}

run_step() {
	local num="$1"
	local title="$2"
	local func_name="$3"

	if ask_yes_no "[${num}/${TOTAL_STEPS}] ${title}"; then
		echo "Running step ${num}: ${title}"
		"${func_name}"
	else
		echo "Skipping step ${num}: ${title}"
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
	vim --headless +PlugInstall +qa
}

step4_configure_zsh() {
	cp "${ENV_REPO}/.bashrc" "${HOME}/"
	sudo apt-get install -y zsh

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

	echo "Setting Zsh as default shell"
	chsh -s "$(command -v zsh)"

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

	build_linux_source 2
	build_linux_source 4
	build_linux_source 5
	build_linux_source 6

	mkdir -p "${LINUX_VSCODE}"
	mkdir -p "${LINUX_ROOT}/linux-qemu"
	if [ -d "/lib/modules/$(uname -r)/build" ]; then
		sudo cp -dR "/lib/modules/$(uname -r)/build" "/lib/modules/$(uname -r)/build.bak"
	fi
	if [ -d "/lib/modules/$(uname -r)/source" ]; then
		sudo cp -dR "/lib/modules/$(uname -r)/source" "/lib/modules/$(uname -r)/source.bak"
	fi
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

	build_tool_chain arm64 aarch64
	build_tool_chain riscv riscv64-lp64d
	build_tool_chain x86 x86-64
}

step7_generate_cross_compiler_env() {
	local get_cross_compiler
	local env_dir
	local shell_hint_found=0
	local ktoolchain_script

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
		local tc_bin
		local env_file
		cross_prefix="$(${get_cross_compiler} "${arch}")"
		tc_target="${cross_prefix%-}"
		tc_bin="${LINUX_TOOL_CHAIN}/${arch}/bin"
		env_file="${env_dir}/${arch}.env"

		cat > "${env_file}" <<EOF
export ARCH="${arch}"
export CROSS_COMPILE="${cross_prefix}"
export TC_TARGET="${tc_target}"
export KTOOLCHAIN_ACTIVE_ARCH="${arch}"
export KTOOLCHAIN_ACTIVE_BIN="${tc_bin}"

case ":\${PATH}:" in
	*":\${KTOOLCHAIN_ACTIVE_BIN}:"*) ;;
	*) export PATH="\${KTOOLCHAIN_ACTIVE_BIN}:\${PATH}" ;;
esac
EOF
	}

	generate_arch_env x86
	generate_arch_env arm64
	generate_arch_env riscv

	ktoolchain_script="${HOME}/scripts/ktoolchain.sh"
	if [ ! -f "${ktoolchain_script}" ] && [ -f "${SCRIPT_DIR}/scripts/ktoolchain.sh" ]; then
		ktoolchain_script="${SCRIPT_DIR}/scripts/ktoolchain.sh"
	fi

	if [ -f "${HOME}/.bashrc" ] && grep -q "ktoolchain.sh" "${HOME}/.bashrc"; then
		shell_hint_found=1
	fi
	if [ -f "${HOME}/.zshrc" ] && grep -q "ktoolchain.sh" "${HOME}/.zshrc"; then
		shell_hint_found=1
	fi

	echo "Generated cross-toolchain env files under ${env_dir}:"
	echo "  - x86.env"
	echo "  - arm64.env"
	echo "  - riscv.env"
	echo "Switch toolchain in current shell with:"
	echo "  source ${ktoolchain_script}"
	echo "  ktoolchain use arm64"

	if [ "${shell_hint_found}" -eq 0 ]; then
		echo "Hint: add 'source ${ktoolchain_script}' to ~/.bashrc or ~/.zshrc for convenience."
	fi
}

echo "Interactive setup started."
echo "Press Enter to accept default [Y] on each step."

run_step 1 "Installing essential SDKs and tools" step1_install_sdks
run_step 2 "Clone/sync develop environment configuration" step2_sync_env_files
run_step 3 "Configuring vim" step3_configure_vim
run_step 4 "Configuring zsh" step4_configure_zsh
run_step 5 "Building linux tree" step5_build_linux_tree
run_step 6 "Installing cross-compiler" step6_install_cross_compiler
run_step 7 "Generate user-space cross-compiler switch scripts" step7_generate_cross_compiler_env

echo "Setup finished."
