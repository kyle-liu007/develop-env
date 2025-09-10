#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $1 <linux version> $2 <arch> $3 <rebuild> $4 <moudle output path, optional>"
    exit 1
fi

linux_version=$(get_linux_version.sh $1)

arch=$2
working_dir=`pwd`
if [ ! -z $4 ]; then
    module_output=$4
else
    module_output=${working_dir}
fi
linux_source=${LINUX_SOURCE}/linux-${linux_version}
linux_output=${LINUX_BUILD}/linux-${linux_version}/${arch}
TARGET=$(uname -r)
KERNEL_MODULES=/lib/modules/${TARGET}
KERNEL_BUILD=${KERNEL_MODULES}/build

#if [ -e cscope.files ]; then
#    code .
#    exit 0
#fi

# test wether C/C++ configuration for vscode exists
#if [ ! -e ${LINUX_VSCODE}/linux-${linux_version}/${arch} ]; then
#    echo "no vscode directory linux-${linux_version}/${arch}"
#    exit 1
#fi

#ln -sf -T ${LINUX_VSCODE}/linux-${linux_version}/${arch} .vscode

# test if vmlinux exists, if not, build kernel
if [ ! -z $3 ]; then
    echo "******* start building linux kernel *******"
    cd ${LINUX_ROOT}
    ./build.sh ${linux_version} ${arch}
#    cp -rf ${linux_output}/include/ ${linux_source}/
#    cp -rf ${linux_output}/arch/${arch}/include/ ${linux_source}/arch/${arch}/
    cd ${working_dir}
fi

# get cscope.files
# copy kernel cscope.files to working_dir
cp ${linux_output}/cscope.files ${working_dir}
# handle .cmd files
{
	find -name "*.cmd"  -exec \
		sed -n -E 's/^source_.* (.*)/\1/p; s/^  (\S.*) \\/\1/p' {} \+ | grep ${working_dir}
} | awk '!a[$0]++' | xargs realpath -es |
	sort -u >> cscope.files
#handle .dep files
{
    find -name "*.dep" -exec \
        sh -c '
        dep_dir=$(dirname {})
        sed -E "s/\\\\//g; s/^.*:\\s*//" {} | awk -vdir=$dep_dir "{for(i=1;i<=NF;i++){  if (\$i ~ /^\/.*$/) { print \$i } else {print dir \"/\" \$i }}}"
        ' {} \;
} | awk '!a[$0]++' | xargs realpath -es |
  sort -u >> cscope.files
awk '!a[$0]++' cscope.files > .cscope.files
mv .cscope.files cscope.files
# cscope analyse
cscope -b -q -k

# generate compile_commands.json
# by default, $working_dir is where your module ouput path, or you should pass it to $3
generate_compdb.py -r ${linux_source} ${module_output} ${linux_output}
#code .
