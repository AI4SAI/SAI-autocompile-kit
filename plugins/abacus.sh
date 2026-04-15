#!/bin/bash
# ============================================================
# plugins/abacus.sh — ABACUS 插件
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="abacus"
REPO="https://github.com/deepmodeling/abacus-develop.git"
BRANCH="LTS"
MODULES="cuda/12.9.1 nccl/2.18.5-cuda12.2 nvhpc/26.3-gnu-cuda12-tuned openmpi/5.0.10-nvhpc26.3-gnu-cuda12-auto fftw/3.3.10 libxc/7.0.0-auto saiblas/2603-gnu-auto elpa/2026.02.001-2603-gnu"
BINARIES=("abacus")

# ABACUS 特有参数
GPU_VER="70"
SKIP_TOOLCHAIN=false

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
ABACUS 编译选项:
  --modules "MOD1 MOD2 .."  覆盖默认 module load 列表
  --gpu-ver VER            GPU compute capability，默认: 70
  --skip-toolchain         跳过 toolchain 依赖安装
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modules)        MODULES="$2";       shift 2 ;;
            --gpu-ver)        GPU_VER="$2";       shift 2 ;;
            --skip-toolchain) SKIP_TOOLCHAIN=true; shift ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    echo "  系统模块:      $MODULES"
    echo "  GPU 版本:      sm_$GPU_VER"
    echo "  跳过toolchain: $SKIP_TOOLCHAIN"
}

# ---------- 预构建：toolchain ----------
plugin_pre_build() {
    TOOLCHAIN_DIR="$SRC_DIR/toolchain"
    INSTALL_DIR="$TOOLCHAIN_DIR/install"

    if $SKIP_TOOLCHAIN; then
        info "跳过 toolchain (--skip-toolchain)"
        [[ ! -f "$INSTALL_DIR/setup" ]] && error "未找到 $INSTALL_DIR/setup，请先运行 toolchain 或去掉 --skip-toolchain"
    else
        info "运行 toolchain 安装依赖 (cereal, rapidjson, LibRI, LibComm)..."
        [[ ! -d "$TOOLCHAIN_DIR" ]] && error "未找到 toolchain 目录: $TOOLCHAIN_DIR"
        cd "$TOOLCHAIN_DIR"
        bash install_abacus_toolchain_new.sh \
            --with-gcc="system" \
            --with-intel="no" \
            --with-amd="no" \
            --math-mode="openblas" \
            --mpi-mode="openmpi" \
            --with-openblas="system" \
            --with-openmpi="system" \
            --with-mpich="no" \
            --with-cmake="system" \
            --with-scalapack="system" \
            --with-libxc="system" \
            --with-fftw="system" \
            --with-elpa="system" \
            --with-cereal="install" \
            --with-rapidjson="install" \
            --with-libtorch="no" \
            --with-nep="no" \
            --with-libnpy="no" \
            --with-libri="install" \
            --with-libcomm="install" \
            --with-4th-openmpi="no" \
            --enable-cuda \
            --gpu-ver="$GPU_VER" \
            2>&1 | tee "$WORK_DIR/toolchain.log"
        TOOLCHAIN_RC=${PIPESTATUS[0]}
        if [[ $TOOLCHAIN_RC -ne 0 ]]; then
            error "toolchain 安装失败 (exit code: $TOOLCHAIN_RC)，请检查 $WORK_DIR/toolchain.log"
        fi
        if grep -qiE '(FAILED|fatal error|patch.*fail|error:)' "$WORK_DIR/toolchain.log"; then
            warn "toolchain 日志中检测到错误关键词，请检查 $WORK_DIR/toolchain.log"
            grep -inE '(FAILED|fatal error|patch.*fail|error:)' "$WORK_DIR/toolchain.log" | head -10
            if [[ "$YES_TO_ALL" == true ]]; then
                warn "--yes 已启用，自动继续"
            else
                read -rp "是否继续编译? [y/N] " _tc_confirm
                case "$_tc_confirm" in
                    [yY]*) warn "用户选择继续" ;;
                    *) error "用户中止，请检查 toolchain 日志" ;;
                esac
            fi
        fi
        info "toolchain 安装完成"
    fi

    # source setup — 用子 shell 测试，再在当前 shell 中 source
    # setup 脚本内部可能有 set -e 或未定义变量，先验证能否正常执行
    if ! (source "$INSTALL_DIR/setup" 2>/dev/null); then
        warn "source $INSTALL_DIR/setup 在子 shell 中返回非零，尝试继续..."
    fi
    set +eu
    source "$INSTALL_DIR/setup" 2>/dev/null || true
    set -e

    # env 脚本额外行：source toolchain setup
    ENV_EXTRAS=("source $INSTALL_DIR/setup")
}

# ---------- 构建 ----------
plugin_build() {
    info "开始 cmake 构建 ABACUS (GPU_VER=sm_${GPU_VER})..."
    cd "$SRC_DIR"

    local build_dir="build_abacus_gnu"
    rm -rf "$build_dir"

    local lapack="${OPENBLAS_ROOT}/lib"
    local scalapack="${ScaLAPACK_ROOT}/lib"
    local elpa="${ELPA_ROOT}"
    local fftw3="${FFTW3_ROOT}"
    local cereal="${INSTALL_DIR}/cereal-master/include/cereal"
    local libxc="${LIBXC_ROOT}"
    local rapidjson="${INSTALL_DIR}/rapidjson-master/"
    local libri="${INSTALL_DIR}/LibRI-master"
    local libcomm="${INSTALL_DIR}/LibComm-master"

    cmake -B "$build_dir" -DCMAKE_INSTALL_PREFIX="$SRC_DIR" \
        -DCMAKE_CXX_COMPILER=g++ \
        -DMPI_CXX_COMPILER=mpicxx \
        -DLAPACK_DIR="$lapack" \
        -DSCALAPACK_DIR="$scalapack" \
        -DELPA_DIR="$elpa" \
        -DFFTW3_DIR="$fftw3" \
        -DCEREAL_INCLUDE_DIR="$cereal" \
        -DLibxc_DIR="$libxc" \
        -DENABLE_LCAO=ON \
        -DENABLE_LIBXC=ON \
        -DUSE_OPENMP=ON \
        -DUSE_ELPA=ON \
        -DENABLE_RAPIDJSON=ON \
        -DRapidJSON_DIR="$rapidjson" \
        -DENABLE_LIBRI=ON \
        -DLIBRI_DIR="$libri" \
        -DLIBCOMM_DIR="$libcomm" \
        -DUSE_CUDA=ON \
        -DENABLE_CUSOLVERMP=ON \
        -DCAL_CUSOLVERMP_PATH="${NVHPC_ROOT}/math_libs/12.9/lib64"

    cmake --build "$build_dir" -j "$JOBS" || error "cmake 编译失败，可进入 $SRC_DIR/$build_dir 排查"
    cmake --install "$build_dir" 2>/dev/null
    info "ABACUS 编译完成"
}

# ---------- 后构建：安装二进制 ----------
plugin_post_build() {
    mkdir -p "$PREFIX/bin"
    if [[ -f "$SRC_DIR/bin/abacus" ]]; then
        cp "$SRC_DIR/bin/abacus" "$PREFIX/bin/"
        info "已安装 abacus 到 $PREFIX/bin/"
    else
        error "未找到编译产物 $SRC_DIR/bin/abacus"
    fi

    ENV_PATH_PREPEND=("$PREFIX/bin")
}
