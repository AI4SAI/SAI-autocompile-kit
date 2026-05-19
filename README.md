# SAI Autocompile Kit

科研软件迭代快、编译环境复杂，本项目将常用软件的编译流程整理为标准化脚本，支持一键编译安装任意 branch 或 release 版本。

## 为什么用

- 统一的编译流程，无需手动处理依赖和环境变量
- 内置管理员选定的工具链（编译器、MPI、数学库等），开箱即用
- 支持指定任意 branch、release 版本、自定义 URL 或本地源码
- 编译完成后自动生成环境脚本和 SLURM 提交模板

## 支持的软件

| 软件 | 默认分支 | 说明 |
|------|---------|------|
| gpumd | master | GPU 分子动力学 |
| lammps | stable | 经典分子动力学 |
| abacus | LTS | 第一性原理计算 |
| qe | develop | Quantum ESPRESSO 第一性原理计算 |
| deepmd-kit | master | 深度势能 |
| mace | main | 机器学习力场 |

## 快速开始

基本语法：

```bash
bash sai-compile.sh <软件名> [选项]
```

### 示例

编译安装 GPUMD（指定 GPU 架构为 sm_80）：

```bash
bash sai-compile.sh gpumd -a sm_80
```

安装 DeePMD-kit 的 `devel` 分支：

```bash
bash sai-compile.sh deepmd-kit -b devel
```

安装 MACE 的 `develop` 分支到指定目录：

```bash
bash sai-compile.sh mace -b develop -p /opt/mace
```

安装 LAMMPS 指定 release 版本：

```bash
bash sai-compile.sh lammps -v 29Aug2024_update4
```

安装 ABACUS（GPU 版本，架构 sm_80）：

```bash
bash sai-compile.sh abacus --gpu-ver 80
```

安装 Quantum ESPRESSO 7.5（默认编译 `pwall`）：

```bash
bash sai-compile.sh qe -v 7.5
```

安装 Quantum ESPRESSO 并指定多个 make target：

```bash
bash sai-compile.sh qe -v 7.5 --target "pw ph pp"
```

## 常用选项

| 选项 | 说明 |
|------|------|
| `-b, --branch BRANCH` | 指定 git 分支 |
| `-v, --version VERSION` | 指定 release/tag 版本 |
| `-u, --url URL` | 从自定义 URL 下载源码 |
| `-l, --local PATH` | 使用本地源码目录或压缩包 |
| `-p, --prefix DIR` | 安装目录（默认当前目录） |
| `-j, --jobs N` | 并行编译线程数（默认全部核心） |
| `--clean` | 编译成功后删除构建目录 |
| `--yes` | 跳过确认提示，直接执行 |
| `-n, --dry-run` | 仅打印步骤，不实际执行 |
| `-h, --help` | 显示帮助信息 |

各软件还有专属选项，使用 `bash sai-compile.sh <软件名> -h` 查看。

## 编译产物

编译成功后会在安装目录生成：

- `<软件名>_env.sh` — 环境脚本，`source` 后即可使用
- `<软件名>.slurm` — SLURM 作业提交模板（如有）

## 开发指南

如需添加新软件支持，请参阅 [develop.md](develop.md)。
