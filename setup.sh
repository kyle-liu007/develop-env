#!/bin/bash

# install essential sdk
echo "[1/7] Installing Linux Kernel SDK..."
sudo apt update && sudo apt install -y \
    build-essential libncurses-dev bison flex \
    libssl-dev libelf-dev bc git fakeroot \
    libudev-dev libpci-dev libiberty-dev \
    openssl dwarves zstd libdw-dev libunwind-dev\
	binutils-dev cpio libslang2-dev udev

echo "[2/7] Clone develop environment configuration"
env_repo=~/develop-env
if [ ! -d ${env_repo} ]; then
	git clone git@github.com:kyle-liu007/develop-env.git ${env_repo}
fi
cp ${env_repo}/.gitconfig ~/ 
cp -ar ${env_repo}/scripts ~/

echo "[3/7] Configuring Vim with vim-plug..."
cp ${env_repo}/.vimrc ~/
if ! command -v vim &> /dev/null; then
	echo "Error: Vim not found. Install Vim first."
	exit 1
fi
if [ ! -f ~/.vim/autoload/plug.vim ]; then
	echo "Installing vim-plug..."
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    	https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
echo "Installing plugins via vim-plug..."
vim --headless +PlugInstall +qa

echo "[4/7] Configuring Zsh..."
cp ${env_repo}/.bashrc ~/
sudo apt-get install -y zsh

if [ ! -d ~/.oh-my-zsh ]; then
	echo "Installing oh-my-zsh..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" ""
fi

if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]; then
	git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi
if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

echo "Setting Zsh as default shell"
chsh -s $(which zsh)
echo "Sourcing .zshrc configuration..."

cp ${env_repo}/.zshrc ~/
cp ${env_repo}/.oh-my-zsh/custom/* ~/.oh-my-zsh/custom/
zsh ~/.zshrc

echo "[5/7] Building linux tree"
cp -ar ${env_repo}/linux/* ${LINUX_ROOT}
mkdir -p ${LINUX_SOURCE}
mkdir -p ${LINUX_VSCODE}
mkdir -p ${LINUX_ROOT}/linux-qemu

echo "[6/7] Installing cross-compiler."
build_tool_chain() {
	arch=$1
	sub_arch=$2
	archive=${sub_arch}--glibc--stable-2025.08-1.tar.xz
	mkdir -p ${LINUX_TOOL_CHAIN}/${arch}

	if [ ! -d ${LINUX_TOOL_CHAIN}/${arch}/bin ]; then
		pushd ${LINUX_TOOL_CHAIN}/${arch}
		if [ ! -f ${archive} ]; then
			wget -O ${archive} \
				https://toolchains.bootlin.com/downloads/releases/toolchains/${sub_arch}/tarballs/${archive}
		fi
		tar -xf ${archive} --strip-components=1
		popd
	fi
}
build_tool_chain arm64 aarch64
build_tool_chain riscv riscv64-lp64d
build_tool_chain x86 x86-64

echo "[7/7] Configuring update-alternatives for cross-compilation..."
config_cross_compiler() {
	link=$1
	name=$2
	if [[ -L ${link} ]]; then
    	sudo update-alternatives --install ${link} ${name} $(readlink -f ${link}) 20
	elif [[ -f ${link} ]]; then
    	sudo cp -a ${link} ${link}-backup
    	sudo update-alternatives --install ${link} ${name} ${link}-backup 20
	fi
	if [[ ${name} == gcc ]]; then
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/x86/bin/$(get_cross_compiler.sh x86)${name}.br_real 10
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/arm64/bin/$(get_cross_compiler.sh arm64)${name}.br_real 10
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/riscv/bin/$(get_cross_compiler.sh riscv)${name}.br_real 10
	else
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/x86/bin/$(get_cross_compiler.sh x86)${name} 10
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/arm64/bin/$(get_cross_compiler.sh arm64)${name} 10
		sudo update-alternatives --install ${link} ${name} ${LINUX_TOOL_CHAIN}/riscv/bin/$(get_cross_compiler.sh riscv)${name} 10
	fi
}

config_cross_compiler /usr/bin/gcc gcc
config_cross_compiler /usr/bin/ld ld

