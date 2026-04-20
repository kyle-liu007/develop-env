# develop-env
environment for daily develop

## 快速开始
`./setup.sh`：交互式执行 7 个初始化步骤，可按提示跳过。

可选细分参数：
- `--arch <x86|arm64|riscv[,..]>`：仅处理指定架构的交叉编译工具链与环境脚本。
- `--kernel <2|4|5|6[,..]>`：仅准备指定内核 key 对应源码。
- `--skip-chsh`：跳过默认 shell 切换。

示例：
- `./setup.sh --arch arm64 --kernel 6`
- `./setup.sh --arch x86,arm64 --skip-chsh`

## 脚本用法
多数脚本依赖以下环境变量：`LINUX_ROOT`、`LINUX_SOURCE`、`LINUX_BUILD`、`LINUX_TOOL_CHAIN`。

### 根目录
- `./setup.sh`：初始化开发环境（安装依赖、同步配置、准备内核源码与工具链）。

### linux/
- `linux/build.sh <linux_version> [arch]`：构建内核、生成 cscope、执行 `modules_prepare`。
- `linux/build_clean.sh <linux_version> [arch]`：清理指定版本与架构的构建输出。

### scripts/
- `source ktoolchain.sh` 后使用：`ktoolchain use x86|arm64|riscv`、`ktoolchain current`、`ktoolchain off`。
- `ktoolchain use <arch>` 会同时导出 `ARCH`、`CROSS_COMPILE` 以及 `CC/CXX/AR/LD/...`，便于普通 `make` 直接使用交叉编译器。
- `source prepare_module_build_env.sh <linux_key> <arch> [rebuild]`：准备模块编译环境并更新 `/lib/modules/$(uname -r)/build`。
- `source unset_module_build_env.sh`：关闭工具链并恢复模块编译环境。
- `generate_kernel_cscope.sh <linux_key> <arch>`：生成当前目录 `cscope.files` 并构建 cscope 数据库。
- `backup_env.sh`：备份配置与脚本，并自动提交推送到 `develop-env` 仓库。
