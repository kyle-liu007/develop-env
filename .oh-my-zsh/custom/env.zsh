# enable shell syntax highlight
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# export env
export LINUX_ROOT=~/linux
export LINUX_SOURCE=${LINUX_ROOT}/linux-source
export LINUX_BUILD=${LINUX_ROOT}/linux-build
export LINUX_TOOL_CHAIN=${LINUX_ROOT}/tool-chain
#export PATH=$PATH:${LINUX_TOOL_CHAIN}/x86/bin/
export LINUX_VSCODE=${LINUX_ROOT}/linux-vscode
export CMAKE_EXPORT_COMPILE_COMMANDS=1
export PATH=$PATH:~/scripts
export PATH=$PATH:~/.local/bin
export DISPLAY=`grep -oP "(?<=nameserver ).+" /etc/resolv.conf`:0.0

export hostip=$(ip route | grep default | awk '{print $3}')
#export hostip=127.0.0.1
export hostport=7897
