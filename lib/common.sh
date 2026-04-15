#!/bin/bash
# ============================================================
# lib/common.sh — 公共工具函数 + pipeline 编排器
# ============================================================

set -eo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 工具函数 ----------
info()  { echo -e "\033[32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[33m[WARN]\033[0m $*"; }
error() { echo -e "\033[31m[ERROR]\033[0m $*"; warn "构建目录已保留: ${WORK_DIR:-unknown} (可用 --local 重试)"; exit 1; }

run() {
    if ${DRY_RUN:-false}; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

call_hook() {
    if type -t "$1" &>/dev/null; then "$1"; fi
}

# ---------- 加载子模块 ----------
source "$LIB_DIR/argparse.sh"
source "$LIB_DIR/source.sh"
source "$LIB_DIR/workdir.sh"
source "$LIB_DIR/modules.sh"
source "$LIB_DIR/confirm.sh"
source "$LIB_DIR/envscript.sh"

# ---------- Pipeline 编排器 ----------
run_pipeline() {
    show_common_params
    call_hook plugin_show_params
    prompt_confirm
    setup_workdir "$SOFTWARE_NAME"
    acquire_source
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] 后续步骤: load modules -> pre_build -> build -> post_build -> generate scripts"
        exit 0
    fi
    load_modules
    call_hook plugin_pre_build
    plugin_build
    call_hook plugin_post_build
    generate_scripts
    BUILD_SUCCESS=true
    info "安装完成！"
}
