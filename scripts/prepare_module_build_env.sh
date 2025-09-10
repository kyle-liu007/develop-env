#!/bin/bash
# ===========================================================
# Need be executed by source to export env
# ===========================================================

if [ $# -lt 2 ]; then
    echo "Usage: $1 <linux version> $2 <arch> $3 <rebuild>"
    exit 1
fi

linux_version=$(get_linux_version.sh $1)

arch=$2
working_dir=`pwd`

linux_source=${LINUX_SOURCE}/linux-${linux_version}
linux_output=${LINUX_BUILD}/linux-${linux_version}/${arch}

build_kernel() {
	unset_module_build_env.sh
	echo "******* start building linux kernel *******"
	pushd ${LINUX_ROOT}
	./build.sh ${linux_version} ${arch}
	popd
}

if [ ! -z $3 ]; then
	build_kernel
fi

# prepare module build headers
kernel_modlib=/lib/modules/$(uname -r)
sudo ln -sfT ${linux_output} ${kernel_modlib}/build
sudo ln -sfT ${linux_output}/source ${kernel_modlib}/source

export ARCH=${arch}

cross_compile=$(get_cross_compiler.sh ${arch})
sudo update-alternatives --set ld ${LINUX_TOOL_CHAIN}/${arch}/bin/${cross_compile}ld
sudo update-alternatives --set gcc ${LINUX_TOOL_CHAIN}/${arch}/bin/${cross_compile}gcc.br_real
