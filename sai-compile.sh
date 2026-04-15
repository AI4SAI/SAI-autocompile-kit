#!/bin/bash
# ============================================================
# sai-compile.sh — SAI 统一编译入口
# ============================================================
# 用法: bash sai-compile.sh <software> [选项]
# 示例: bash sai-compile.sh lammps -v 29Aug2024_update4 -p /opt/lammps
#       bash sai-compile.sh gpumd -a sm_80
#       bash sai-compile.sh cp2k --gpu-ver V100

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "用法: bash sai-compile.sh <software> [选项]"
    echo ""
    echo "支持的软件:"
    for plugin in "$SCRIPT_DIR"/plugins/*.sh; do
        echo "  - $(basename "$plugin" .sh)"
    done
    echo ""
    echo "示例:"
    echo "  bash sai-compile.sh gpumd -a sm_80"
    echo "  bash sai-compile.sh lammps -v 29Aug2024_update4"
    echo "  bash sai-compile.sh abacus --gpu-ver 80"
    echo ""
    echo "使用 bash sai-compile.sh <software> -h 查看软件特有选项"
    exit 0
fi

SOFTWARE="$1"; shift

# 加载插件（插件设置默认变量）
PLUGIN_FILE="$SCRIPT_DIR/plugins/${SOFTWARE}.sh"
if [[ ! -f "$PLUGIN_FILE" ]]; then
    echo -e "\033[31m[ERROR]\033[0m 未知软件: $SOFTWARE"
    echo "支持的软件:"
    for plugin in "$SCRIPT_DIR"/plugins/*.sh; do
        echo "  - $(basename "$plugin" .sh)"
    done
    exit 1
fi

source "$PLUGIN_FILE"

# 加载公共库（在插件之后，这样插件的默认值已设置）
source "$SCRIPT_DIR/lib/common.sh"

# 两遍参数解析
parse_common_args "$@"
if type -t plugin_parse_args &>/dev/null; then
    plugin_parse_args "${PLUGIN_ARGS[@]}"
fi

# 运行 pipeline
run_pipeline
