#!/bin/bash
# ============================================================
# plugins/gpumd.sh — GPUMD 插件
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="gpumd"
REPO="https://github.com/brucefan1983/GPUMD.git"
BRANCH="master"
MODULES="cuda/12.9.1"
BINARIES=("gpumd" "nep")
SRC_SUBDIR="src"
CLONE_DIR_NAME="GPUMD"

# GPUMD 特有参数
ARCH="sm_70"

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
GPUMD 编译选项:
  --modules "MOD1 MOD2 .."  覆盖默认 module load 列表，默认: cuda/12.9.1
  -a, --arch SM             GPU compute capability，默认: sm_70
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modules) MODULES="$2"; shift 2 ;;
            -a|--arch) ARCH="$2";    shift 2 ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    echo "  系统模块:      $MODULES"
    echo "  GPU 架构:      $ARCH"
}

# ---------- 构建 ----------
plugin_build() {
    # 修改 makefile 中的 GPU 架构
    local makefile="$SRC_DIR/makefile"
    [[ ! -f "$makefile" ]] && makefile="$SRC_DIR/Makefile"
    [[ ! -f "$makefile" ]] && error "未找到 makefile: $SRC_DIR"

    info "设置 GPU 架构: $ARCH"
    sed -i "s/sm_[0-9]\{2,3\}/$ARCH/g" "$makefile"

    info "开始编译 (make -j$JOBS)..."
    cd "$SRC_DIR"
    make -j"$JOBS" || error "编译失败"
}

# ---------- 后构建：安装二进制 ----------
plugin_post_build() {
    mkdir -p "$PREFIX"
    local installed=()
    for bin in "${BINARIES[@]}"; do
        if [[ -f "$SRC_DIR/$bin" ]]; then
            cp "$SRC_DIR/$bin" "$PREFIX/"
            installed+=("$bin")
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        error "未找到编译产物 (${BINARIES[*]})"
    fi

    info "已安装到 $PREFIX/: ${installed[*]}"

    ENV_PATH_PREPEND=("$PREFIX")
}
