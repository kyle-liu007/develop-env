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

#rm -r ${source}/include/generated/
#rm -r ${source}/include/config/
#rm -r ${source}/arch/${arch}/include/generated/

pushd ${source}
make clean O=${output}
popd
