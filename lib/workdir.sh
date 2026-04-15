#!/bin/bash
# ============================================================
# lib/workdir.sh — 工作目录创建 + 日志 + cleanup trap
# ============================================================

BUILD_SUCCESS=false

setup_workdir() {
    local name="${1:-build}"
    mkdir -p "$PREFIX"

    if [[ -n "${BUILD_DIR_OVERRIDE:-}" ]]; then
        WORK_DIR="${PREFIX}/${BUILD_DIR_OVERRIDE}"
        mkdir -p "$WORK_DIR"
    else
        local ver_tag="${VERSION:-${BRANCH:-unknown}}"
        local date_tag=$(date +%Y%m%d)
        local dir_name="${name}_build_${ver_tag}_${date_tag}"
        WORK_DIR="${PREFIX}/${dir_name}"
        if [[ -d "$WORK_DIR" ]]; then
            WORK_DIR="${WORK_DIR}_$(head -c4 /dev/urandom | xxd -p)"
        fi
        mkdir -p "$WORK_DIR"
    fi
    info "工作目录: $WORK_DIR"

    # 所有 stdout/stderr 同时输出到屏幕和日志文件
    LOG_FILE="$WORK_DIR/${name}_compile.log"
    info "编译日志: $LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1

    trap _cleanup EXIT
    trap 'warn "收到中断信号，退出..."; exit 1' INT TERM
}

_cleanup() {
    if $BUILD_SUCCESS; then
        if [[ "${CLEAN_BUILD:-false}" == true ]]; then
            [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR" && info "已清理工作目录: $WORK_DIR"
        else
            info "构建目录已保留: $WORK_DIR"
            info "编译日志: $LOG_FILE"
        fi
    else
        warn "编译未成功，构建目录已保留: $WORK_DIR"
        warn "编译日志: $LOG_FILE"
        warn "可使用 --local $WORK_DIR/<source-dir> 重试"
    fi
}
