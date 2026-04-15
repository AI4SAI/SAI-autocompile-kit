# 开发指南：添加新软件支持

## 整体流程

添加一个新软件只需两步：

1. 在 `plugins/` 目录下创建 `<软件名>.sh` 插件文件
2. （可选）在 `slurm_template/` 下添加对应的 SLURM 模板

框架会自动识别 `plugins/` 下的插件，无需修改其他文件。

## 插件结构

每个插件需要定义以下变量和函数：

### 必需变量

| 变量 | 说明 |
|------|------|
| `SOFTWARE_NAME` | 软件名称（与文件名一致） |
| `REPO` | GitHub 仓库地址 |
| `BRANCH` | 默认分支 |
| `MODULES` | 需要加载的系统模块（空格分隔） |
| `BINARIES` | 编译产物的可执行文件列表（数组） |

### 必需函数

| 函数 | 说明 |
|------|------|
| `plugin_usage` | 打印插件专属选项的帮助信息 |
| `plugin_parse_args` | 解析插件专属的命令行参数 |
| `plugin_show_params` | 展示插件参数（确认步骤中显示） |
| `plugin_build` | 核心编译逻辑 |

### 可选函数

| 函数 | 说明 |
|------|------|
| `plugin_pre_build` | 编译前的准备工作（如激活 conda 环境） |
| `plugin_post_build` | 编译后的安装操作（如拷贝二进制文件） |

### 执行流程

框架按以下顺序调用插件：

```
plugin_show_params → 用户确认 → acquire_source → load_modules
→ plugin_pre_build → plugin_build → plugin_post_build → generate_scripts
```

## 示例：添加 calculator 软件

假设要添加一个名为 `calculator` 的软件，它使用 CMake 构建，依赖 GCC 和 OpenMPI。

创建 `plugins/calculator.sh`：

```bash
#!/bin/bash
# ============================================================
# plugins/calculator.sh — Calculator 插件
# ============================================================

# ---------- 插件默认值 ----------
SOFTWARE_NAME="calculator"
REPO="https://github.com/example/calculator.git"
BRANCH="main"
MODULES="gcc/13.2.0 openmpi/5.0.8"
BINARIES=("calculator")

# Calculator 特有参数
ENABLE_GPU=false

# ---------- 插件帮助 ----------
plugin_usage() {
    cat <<'EOF'
Calculator 编译选项:
  --modules "MOD1 MOD2 .."  覆盖默认 module load 列表
  --gpu                     启用 GPU 支持
EOF
}

# ---------- 插件参数解析 ----------
plugin_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modules)  MODULES="$2"; shift 2 ;;
            --gpu)      ENABLE_GPU=true; shift ;;
            *) error "未知选项: $1 (使用 -h 查看帮助)" ;;
        esac
    done
}

# ---------- 插件参数展示 ----------
plugin_show_params() {
    echo "  系统模块:      $MODULES"
    echo "  GPU 支持:      $ENABLE_GPU"
}

# ---------- 构建 ----------
plugin_build() {
    local build_dir="$SRC_DIR/build"
    mkdir -p "$build_dir" && cd "$build_dir"

    local cmake_flags="-DCMAKE_INSTALL_PREFIX=$PREFIX"
    if $ENABLE_GPU; then
        cmake_flags+=" -DUSE_GPU=ON"
    fi

    info "CMake 配置..."
    run cmake $cmake_flags ..

    info "开始编译 (make -j$JOBS)..."
    run make -j"$JOBS" || error "编译失败"
}

# ---------- 后构建：安装 ----------
plugin_post_build() {
    cd "$SRC_DIR/build"
    run make install || error "安装失败"
    info "已安装到 $PREFIX/"

    ENV_PATH_PREPEND=("$PREFIX/bin")
}
```

完成后即可使用：

```bash
# 默认编译
bash sai-compile.sh calculator

# 启用 GPU，指定分支
bash sai-compile.sh calculator --gpu -b develop

# 安装指定版本到自定义目录
bash sai-compile.sh calculator -v 2.0.0 -p /opt/calculator
```

## 注意事项

- 插件文件名必须与 `SOFTWARE_NAME` 一致
- `plugin_build` 中可通过 `$SRC_DIR` 访问源码目录，`$PREFIX` 访问安装目录，`$JOBS` 获取并行数
- 编译失败时调用 `error "消息"` 即可，框架会自动保留构建目录并提示用户
- 如需设置环境变量，将路径写入 `ENV_PATH_PREPEND` 数组，框架会自动生成环境脚本
