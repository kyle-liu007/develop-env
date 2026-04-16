#!/bin/bash

is_sourced() {
	[ "${BASH_SOURCE[0]}" != "$0" ]
}

finish() {
	local code="$1"
	if is_sourced; then
		return "${code}"
	fi
	exit "${code}"
}

if ! declare -F ktoolchain >/dev/null 2>&1; then
	echo "Error: ktoolchain not found in current shell." >&2
	echo "Run: source ~/scripts/ktoolchain.sh" >&2
	finish 1
fi

if ! ktoolchain off; then
	finish 1
fi

kernel_modlib="/lib/modules/$(uname -r)"
if [ -d "${kernel_modlib}/build.bak" ]; then
	sudo cp -dR "${kernel_modlib}/build.bak" "${kernel_modlib}/build"
fi
if [ -d "${kernel_modlib}/source.bak" ]; then
	sudo cp -dR "${kernel_modlib}/source.bak" "${kernel_modlib}/source"
fi
