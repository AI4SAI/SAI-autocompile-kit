#!/bin/bash
# ============================================================
# plugins/qe.sh — Quantum ESPRESSO 插件
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="qe"
REPO="https://gitlab.com/QEF/q-e.git"
BRANCH="develop"
MODULES="nvhpc/26.3-pgi-cuda12-tuned openmpi/5.0.10-nvhpc26.3-pgi-cuda12-auto fftw/3.3.10 libxc/7.0.0-auto saiblas/2603-gnu-auto hdf5/1.14.6-pgi-ompi508"
BINARIES=("pw.x")

# QE 特有参数
CUDA_RUNTIME="12.9"
CUDA_CC="70,cc75,cc80,cc86,cc89,cc90"
GPU_ARCH="70,75,80,86,89,90"
MAKE_TARGET="pwall"
CONFIGURE_EXTRA=""

QE_CORE_TARGETS="pw ph hp pwcond neb pp pwall cp all_currents tddfpt gwl ld1 xspectra couple epw kcw pioud gui all"
QE_THIRD_PARTY_TARGETS="gipaw w90 want yambo d3q"
QE_OPERATION_TARGETS="doc links install tar depend clean veryclean distclean tar-gui tar-qe-modes"
QE_VALID_TARGETS="$QE_CORE_TARGETS $QE_THIRD_PARTY_TARGETS $QE_OPERATION_TARGETS"

# QE GitLab tag 格式: qe-7.5。允许用户传 -v 7.5 或 -v qe-7.5。
release_url_fn() {
    local repo_base="$1" version="$2"
    local tag="$version"
    [[ "$tag" == qe-* ]] || tag="qe-${tag}"
    echo "${repo_base}/-/archive/${tag}/q-e-${tag}.tar.gz"
}

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
Quantum ESPRESSO 编译选项:
  --modules "MOD1 MOD2 .."      覆盖默认 module load 列表
  --cuda-runtime VER            CUDA runtime 版本，默认: 12.9
  --cuda-cc "LIST"              configure --with-cuda-cc，默认: 70,cc75,cc80,cc86,cc89,cc90
  --gpu-arch "LIST"             make.inc GPU_ARCH，默认: 70,75,80,86,89,90
  --target "T1 T2 .."           make target，默认: pwall
  --configure-extra "FLAGS"     追加任意 configure 参数

可用 make target:
  Core packages:
    pw ph hp pwcond neb pp pwall cp all_currents tddfpt gwl ld1 xspectra couple epw kcw pioud gui all

  Third-party packages:
    gipaw w90 want yambo d3q

  Suite operations:
    doc links install tar depend clean veryclean distclean tar-gui tar-qe-modes
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modules)          MODULES="$2";         shift 2 ;;
            --cuda-runtime)     CUDA_RUNTIME="$2";    shift 2 ;;
            --cuda-cc)          CUDA_CC="$2";         shift 2 ;;
            --gpu-arch)         GPU_ARCH="$2";        shift 2 ;;
            --target)           MAKE_TARGET="$2";     shift 2 ;;
            --configure-extra)  CONFIGURE_EXTRA="$2"; shift 2 ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
    _validate_make_targets
}

_validate_make_targets() {
    local target ok valid
    for target in $MAKE_TARGET; do
        ok=false
        for valid in $QE_VALID_TARGETS; do
            if [[ "$target" == "$valid" ]]; then
                ok=true
                break
            fi
        done
        $ok || error "未知 QE make target: $target (使用 -h 查看可用 target)"
    done
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    echo "  系统模块:      $MODULES"
    echo "  CUDA runtime:  $CUDA_RUNTIME"
    echo "  CUDA CC:       $CUDA_CC"
    echo "  GPU_ARCH:      $GPU_ARCH"
    echo "  Make target:   $MAKE_TARGET"
    echo "  HDF5:          enabled (--with-hdf5=\${HDF5_ROOT})"
    if [[ -n "$CONFIGURE_EXTRA" ]]; then
        echo "  ---- 额外 configure 参数 ----"
        echo "  $CONFIGURE_EXTRA"
    fi
}

# ---------- 预构建：兼容参考构建流程中的手工修正 ----------
plugin_pre_build() {
    local configure_file="$SRC_DIR/install/configure"
    if [[ -f "$configure_file" ]] && grep -q "XC_MAJOR_VERSION.*tr -dc '1-9'" "$configure_file"; then
        info "修正 install/configure 中 LibXC version 解析..."
        sed -i "s/tr -dc '1-9'/tr -dc '0-9'/g" "$configure_file"
    fi
}

# ---------- 构建 ----------
plugin_build() {
    info "开始 configure 构建 Quantum ESPRESSO (target: $MAKE_TARGET)..."
    cd "$SRC_DIR"

    [[ -n "${CUDA_HOME:-}" ]] || error "CUDA_HOME 未设置，请检查 cuda module 是否正确加载"
    [[ -d "$CUDA_HOME" ]] || error "CUDA_HOME 不存在: $CUDA_HOME"
    [[ -n "${HDF5_ROOT:-}" ]] || error "HDF5_ROOT 未设置，请检查 hdf5 module 是否正确加载"
    [[ -d "$HDF5_ROOT" ]] || error "HDF5_ROOT 不存在: $HDF5_ROOT"

    CUDADIR="$CUDA_HOME" ./configure \
        --prefix="$PREFIX" \
        --with-cuda="$CUDA_HOME" \
        --with-cuda-runtime="$CUDA_RUNTIME" \
        --with-cuda-cc="$CUDA_CC" \
        --enable-openmp \
        --with-cuda-mpi \
        --with-hdf5="$HDF5_ROOT" \
        $CONFIGURE_EXTRA || error "configure 失败，可进入 $SRC_DIR 排查"

    if [[ -f make.inc ]]; then
        info "设置 make.inc GPU_ARCH=$GPU_ARCH"
        if grep -q '^GPU_ARCH[[:space:]]*=' make.inc; then
            sed -i "s/^GPU_ARCH[[:space:]]*=.*/GPU_ARCH=$GPU_ARCH/" make.inc
        else
            echo "GPU_ARCH=$GPU_ARCH" >> make.inc
        fi
    else
        error "configure 后未找到 make.inc"
    fi

    info "开始编译: make $MAKE_TARGET -j$JOBS"
    make $MAKE_TARGET -j"$JOBS" || error "make $MAKE_TARGET 失败，可进入 $SRC_DIR 排查"

    info "开始安装: make install"
    make install || error "make install 失败"
    info "Quantum ESPRESSO 编译安装完成"
}

# ---------- 后构建：设置环境路径 ----------
plugin_post_build() {
    if [[ ! -x "$PREFIX/bin/pw.x" ]]; then
        error "未找到编译产物 $PREFIX/bin/pw.x"
    fi

    ENV_PATH_PREPEND=("$PREFIX/bin")
    ENV_LD_LIBRARY_PATH_PREPEND=("$PREFIX/lib" "$PREFIX/lib64")
}
