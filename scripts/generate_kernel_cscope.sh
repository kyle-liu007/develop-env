#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $1 <linux version> $2 <arch>"
    exit 1
fi

linux_version=$(get_linux_version.sh $1)

arch=$2
working_dir=`pwd`
linux_source=${LINUX_SOURCE}/linux-${linux_version}
linux_output=${LINUX_BUILD}/linux-${linux_version}/${arch}
TARGET=$(uname -r)
KERNEL_MODULES=/lib/modules/${TARGET}
KERNEL_BUILD=${KERNEL_MODULES}/build

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