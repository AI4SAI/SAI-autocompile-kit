#!/bin/bash
# ============================================================
# plugins/lammps.sh — LAMMPS 插件
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="lammps"
REPO="https://github.com/lammps/lammps.git"
BRANCH="stable"
MODULES="aocl/5.0.0-gcc openmpi/5.0.8-nvhpc24.5-gnu-auto fftw/3.3.10 cmake/3.31.6"
BINARIES=("lmp")

# LAMMPS 特有参数
ARCH="sm_70"
DEFAULT_PACKAGES="EXTRA-COMPUTE EXTRA-COMMAND EXTRA-DUMP EXTRA-FIX EXTRA-MOLECULE EXTRA-PAIR KSPACE MANYBODY MOLECULE OPENMP PLUGIN RIGID GPU"
CUSTOM_PACKAGES=""
ADD_PACKAGES=""
REMOVE_PACKAGES=""
CMAKE_EXTRA=""

# LAMMPS release URL 格式不同
release_url_fn() {
    local repo_base="$1" version="$2"
    echo "${repo_base}/archive/refs/tags/stable_${version}.tar.gz"
}

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
LAMMPS 编译选项:
  --modules "MOD1 MOD2 .."  覆盖默认 module load 列表
  --arch SM                GPU compute capability，默认: sm_70

Package 控制:
  --packages "P1 P2 .."   完全覆盖默认 package 列表
  --add-pkg "P1 P2 .."    在默认列表基础上追加 package
  --remove-pkg "P1 P2 .." 从默认列表中移除 package

外部库 / 自定义 cmake 参数:
  --cmake-extra "FLAGS"    追加任意 cmake 参数
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modules)     MODULES="$2";          shift 2 ;;
            --arch)        ARCH="$2";             shift 2 ;;
            --packages)    CUSTOM_PACKAGES="$2";  shift 2 ;;
            --add-pkg)     ADD_PACKAGES="$2";     shift 2 ;;
            --remove-pkg)  REMOVE_PACKAGES="$2";  shift 2 ;;
            --cmake-extra) CMAKE_EXTRA="$2";      shift 2 ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
}

# ---------- Package 计算 ----------
_compute_packages() {
    local pkgs
    if [[ -n "$CUSTOM_PACKAGES" ]]; then
        pkgs="$CUSTOM_PACKAGES"
    else
        pkgs="$DEFAULT_PACKAGES"
    fi
    [[ -n "$ADD_PACKAGES" ]] && pkgs="$pkgs $ADD_PACKAGES"
    if [[ -n "$REMOVE_PACKAGES" ]]; then
        for rm_pkg in $REMOVE_PACKAGES; do
            pkgs=$(echo "$pkgs" | sed "s/\b${rm_pkg}\b//g")
        done
    fi
    echo "$pkgs" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' '
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    FINAL_PACKAGES=$(_compute_packages)
    echo "  系统模块:      $MODULES"
    echo "  GPU 架构:      $ARCH"
    echo "  ---- 启用的 Packages ----"
    echo "  $FINAL_PACKAGES"
    if [[ -n "$CMAKE_EXTRA" ]]; then
        echo "  ---- 额外 cmake 参数 ----"
        echo "  $CMAKE_EXTRA"
    fi
}

# ---------- 预构建：生成 cmake preset ----------
plugin_pre_build() {
    FINAL_PACKAGES=$(_compute_packages)
    BUILD_DIR="$SRC_DIR/build"
    mkdir -p "$BUILD_DIR"

    # basic.cmake
    local basic_cmake="$BUILD_DIR/basic.cmake"
    info "生成 basic.cmake (启用 $(echo $FINAL_PACKAGES | wc -w) 个 packages)..."
    {
        echo "# auto-generated basic.cmake"
        echo ""
        echo "set(ALL_PACKAGES ${FINAL_PACKAGES})"
        echo ""
        echo 'foreach(PKG ${ALL_PACKAGES})'
        echo '  set(PKG_${PKG} ON CACHE BOOL "" FORCE)'
        echo 'endforeach()'
    } > "$basic_cmake"

    # kokkos-cuda.cmake
    local kokkos_cmake="$BUILD_DIR/kokkos-cuda.cmake"
    info "生成 kokkos-cuda.cmake..."
    cat > "$kokkos_cmake" <<'KOKKOS_EOF'
# preset that enables KOKKOS and selects CUDA compilation with OpenMP
set(PKG_KOKKOS ON CACHE BOOL "" FORCE)
set(Kokkos_ENABLE_SERIAL ON CACHE BOOL "" FORCE)
set(Kokkos_ENABLE_OPENMP ON CACHE BOOL "" FORCE)
set(Kokkos_ENABLE_CUDA   ON CACHE BOOL "" FORCE)
set(Kokkos_ARCH_VOLTA70 ON CACHE BOOL "" FORCE)
set(Kokkos_ARCH_ZEN3 ON CACHE BOOL "" FORCE)
set(BUILD_OMP ON CACHE BOOL "" FORCE)
get_filename_component(NVCC_WRAPPER_CMD ${CMAKE_CURRENT_SOURCE_DIR}/../lib/kokkos/bin/nvcc_wrapper ABSOLUTE)
set(CMAKE_CXX_COMPILER ${NVCC_WRAPPER_CMD} CACHE FILEPATH "" FORCE)
set(FFT_KOKKOS "CUFFT" CACHE STRING "" FORCE)
set(Kokkos_ENABLE_DEPRECATION_WARNINGS OFF CACHE BOOL "" FORCE)
KOKKOS_EOF
}

# ---------- 构建 ----------
plugin_build() {
    info "开始 cmake 构建 LAMMPS (ARCH=$ARCH)..."
    cd "$BUILD_DIR"

    cmake -D CMAKE_INSTALL_PREFIX="$PREFIX" \
          -C "$BUILD_DIR/basic.cmake" \
          -C "$BUILD_DIR/kokkos-cuda.cmake" \
          -D BUILD_SHARED_LIBS=ON \
          -D GPU_API=CUDA \
          -D GPU_ARCH="$ARCH" \
          -D CUDA_MPS_SUPPORT=ON \
          $CMAKE_EXTRA \
          ../cmake || error "cmake 配置失败，可进入 $BUILD_DIR 排查"

    info "cmake 配置完成，开始编译 (make -j$JOBS)..."
    cmake --build . -j "$JOBS" || error "cmake 编译失败，可进入 $BUILD_DIR 排查"
    cmake --install .
    info "LAMMPS 编译安装完成"
}

# ---------- 后构建：设置环境路径 ----------
plugin_post_build() {
    ENV_PATH_PREPEND=("$PREFIX/bin")
    ENV_LD_LIBRARY_PATH_PREPEND=("$PREFIX/lib")
}
