#!/bin/bash
# ============================================================
# lib/argparse.sh — 公共参数两遍解析
# ============================================================

# 公共默认值（REPO/BRANCH 由插件预设，这里不覆盖）
SOURCE_MODE="github_clone"
VERSION=""
URL=""
LOCAL_PATH=""
PREFIX="$(pwd)"
JOBS=$(nproc)
DRY_RUN=false
BUILD_DIR_OVERRIDE=""          # 用户指定的构建目录
CLEAN_BUILD=false              # 编译成功后是否删除构建目录
YES_TO_ALL=false               # 跳过所有交互确认

# 插件剩余参数
PLUGIN_ARGS=()

# ---------- 公共 usage 头部 ----------
show_common_usage() {
    cat <<EOF
下载源 (四选一，默认从 GitHub 克隆):
  -v, --version VERSION    从 GitHub 下载指定 release 版本
  -u, --url URL            从指定 URL 下载压缩包 (支持 tar.gz/tar.bz2/tar.xz)
  -l, --local PATH         使用本地已有的压缩包或已解压目录
  -r, --repo URL           GitHub 仓库地址
  -b, --branch BRANCH      克隆时使用的分支

通用选项:
  -j, --jobs N             并行编译数，默认: nproc (当前: $(nproc))
  -p, --prefix DIR         安装目录，默认: ./
  --build-dir DIR          指定构建目录名，默认: {software}_build_{version}_{date}
  --clean                  编译成功后删除构建目录（默认保留）
  --yes                    跳过所有交互确认，默认全部选 yes
  -n, --dry-run            仅打印将要执行的步骤，不实际执行
  -h, --help               显示帮助信息
EOF
}

usage() {
    echo "用法: bash sai-compile.sh $SOFTWARE_NAME [选项]"
    echo ""
    show_common_usage
    if type -t plugin_usage &>/dev/null; then
        echo ""
        plugin_usage
    fi
    exit 0
}

# ---------- 第一遍：消费公共参数 ----------
parse_common_args() {
    PLUGIN_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)  VERSION="$2"; SOURCE_MODE="github_release"; shift 2 ;;
            -u|--url)      URL="$2";     SOURCE_MODE="url";            shift 2 ;;
            -l|--local)    LOCAL_PATH="$2"; SOURCE_MODE="local";       shift 2 ;;
            -r|--repo)     REPO="$2";       shift 2 ;;
            -b|--branch)   BRANCH="$2";     shift 2 ;;
            -p|--prefix)   PREFIX="$2";     shift 2 ;;
            -j|--jobs)     JOBS="$2";       shift 2 ;;
            --build-dir)   BUILD_DIR_OVERRIDE="$2"; shift 2 ;;
            --clean)       CLEAN_BUILD=true;  shift ;;
            --yes)         YES_TO_ALL=true;   shift ;;
            -n|--dry-run)  DRY_RUN=true;    shift ;;
            -h|--help)     usage ;;
            *)             PLUGIN_ARGS+=("$1"); shift ;;
        esac
    done

    # 如果插件设了默认 REPO/BRANCH 但用户没覆盖，保留插件默认值
    # （插件在 source 之前已设置 REPO/BRANCH，这里只在用户显式传参时覆盖）
}
