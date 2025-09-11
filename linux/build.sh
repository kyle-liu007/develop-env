#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $1 <linux version> $2 <arch>"
    exit 1
fi

linux_version=$1
arch=$2
export PATH=$PATH:${LINUX_TOOL_CHAIN}/${arch}/bin/
cross_compile=$(get_cross_compiler.sh ${arch})
source=${LINUX_SOURCE}/linux-${linux_version}
output=${LINUX_BUILD}/linux-${linux_version}/${arch}

pushd ${source}

if [ ! -e ${output} ]; then
    mkdir -p ${output}
fi

#make mrproper O=${output}

if [ ! -f ${output}/.config ]; then
    make ARCH=${arch} CROSS_COMPILE=${cross_compile} defconfig O=${output}
fi
make ARCH=${arch} CROSS_COMPILE=${cross_compile} menuconfig O=${output}
make ARCH=${arch} CROSS_COMPILE=${cross_compile} -j O=${output}
make ARCH=${arch} CROSS_COMPILE=${cross_compile} COMPILED_SOURCE=1 KBUILD_ABS_SRCTREE=1 cscope O=${output}
make ARCH=${arch} CROSS_COMPILE=${cross_compile} modules_prepare O=${output}
popd
