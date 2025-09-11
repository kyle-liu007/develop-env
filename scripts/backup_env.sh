#!/bin/bash
env_repo=~/develop-env

echo "[1/3] Copy config and script files."
cp ~/.vimrc ${env_repo}
cp ~/.zshrc ${env_repo}
cp ~/.bashrc ${env_repo}
cp ~/.gitconfig ${env_repo}
cp -a ~/scripts/* ${env_repo}/scripts
cp -a ${LINUX_ROOT}/*.sh ${env_repo}/linux

# backup .config files
echo "[2/3] Copy linux .config files."
find "${LINUX_BUILD}" -name ".config" -type f | while read config_file; do
	rel_path="${config_file#$LINUX_BUILD/}"
	dest_dir="${env_repo}/linux/linux-build/$(dirname "$rel_path")"
	dest_file="$dest_dir/.config"

	mkdir -p "$dest_dir"
	cp "$config_file" "$dest_file"
done

echo "[3/3] Commit and push to remote."
pushd ${env_repo}
if git status --porcelain | grep -q '^[ MADRCU?][ MDAU?TRC ]'; then
	COMMIT_MSG="backup $(date '+%Y-%m-%d %H:%M:%S')"

	git add -A .
	git commit -m "$COMMIT_MSG"
	git push origin
fi
popd
