#!/bin/bash
# ============================================================
# plugins/mace.sh — MACE 插件 (Python 包)
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="mace"
REPO="https://github.com/ACEsuit/mace.git"
BRANCH="main"
MODULES=""
BUILD_TYPE="python"
BASE_ENV="/opt/envs/mace0.3.15.env"
PIP_INSTALL_ARGS="--ignore-installed --no-deps"
PYPI_MODE=false
PYPI_PACKAGE="mace-torch"

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
MACE 安装选项:
  --base-env PATH          base conda env 脚本路径，默认: /opt/envs/mace0.3.15.env
  --pip-args "ARGS"        额外 pip install 参数，默认: --ignore-installed --no-deps
  --pypi                   从 PyPI 安装（跳过源码获取）
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-env)  BASE_ENV="$2";         shift 2 ;;
            --pip-args)  PIP_INSTALL_ARGS="$2";  shift 2 ;;
            --pypi)      PYPI_MODE=true; SKIP_SOURCE=true; shift ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    echo "  Base env:      $BASE_ENV"
    echo "  PyPI 模式:     $PYPI_MODE"
    if [[ -n "$PIP_INSTALL_ARGS" ]]; then
        echo "  pip 额外参数:  $PIP_INSTALL_ARGS"
    fi
}

# ---------- 预构建：激活 base env ----------
plugin_pre_build() {
    info "激活 base conda env: $BASE_ENV"
    set +eu
    source "$BASE_ENV" 2>/dev/null || true
    set -e
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    info "Python 版本: $PYTHON_VERSION"
}

# ---------- 构建 ----------
plugin_build() {
    if [[ "$PYPI_MODE" == true ]]; then
        info "从 PyPI 安装 ${PYPI_PACKAGE}..."
        pip install --prefix="$PREFIX" $PIP_INSTALL_ARGS "$PYPI_PACKAGE"
    else
        info "从源码安装 mace..."
        cd "$SRC_DIR"
        pip install --prefix="$PREFIX" $PIP_INSTALL_ARGS .
    fi
}

# ---------- 后构建 ----------
plugin_post_build() {
    local site_packages="$PREFIX/lib/python${PYTHON_VERSION}/site-packages"
    ENV_PATH_PREPEND=("$PREFIX/bin")
    ENV_EXTRAS=(
        "export PYTHONPATH=\"${site_packages}:\${PYTHONPATH:-}\""
    )
    info "已安装到 $PREFIX"
}
