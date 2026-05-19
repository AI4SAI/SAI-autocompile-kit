#!/bin/bash
# ============================================================
# lib/source.sh — 源码获取（4种模式 + smart_extract）
# ============================================================

# 插件可设置的变量:
#   SRC_SUBDIR=""           — 源码在解压目录下的子路径 (如 GPUMD 的 "src")
#   SKIP_SOURCE=false       — 跳过源码获取 (Python 包直接 pip install 时)
#   CLONE_DIR_NAME=""       — git clone 目标目录名 (默认: $SOFTWARE_NAME)
#   RELEASE_URL_FN          — 函数，接收 REPO_BASE 和 VERSION，输出 tarball URL
#                             默认: ${REPO_BASE}/archive/refs/tags/v${VERSION}.tar.gz

# ---------- 智能解压 ----------
smart_extract() {
    local archive="$1" dest="$2"
    case "$archive" in
        *.tar.bz2|*.tbz2) run tar -xjf "$archive" -C "$dest" ;;
        *.tar.gz|*.tgz)   run tar -xzf "$archive" -C "$dest" ;;
        *.tar.xz|*.txz)   run tar -xJf "$archive" -C "$dest" ;;
        *.zip)            run unzip -qo "$archive" -d "$dest" ;;
        *) error "不支持的压缩格式: $archive" ;;
    esac
}

# ---------- 默认 release URL 构造 ----------
_default_release_url() {
    local repo_base="$1" version="$2"
    echo "${repo_base}/archive/refs/tags/v${version}.tar.gz"
}

# ---------- 查找解压后的源码目录 ----------
_find_src_dir() {
    local search_dir="$1"
    local found
    found=$(find "$search_dir" -maxdepth 1 -type d ! -name "$(basename "$search_dir")" | head -1)
    echo "$found"
}

# ---------- 主函数 ----------
acquire_source() {
    if [[ "${SKIP_SOURCE:-false}" == true ]]; then
        info "跳过源码获取 (SKIP_SOURCE=true)"
        return 0
    fi

    local clone_name="${CLONE_DIR_NAME:-$SOFTWARE_NAME}"

    info "源码获取方式: $SOURCE_MODE"
    SRC_DIR=""

    case "$SOURCE_MODE" in
        github_clone)
            info "从 $REPO 克隆分支 $BRANCH..."
            run git clone --depth 1 --branch "$BRANCH" "$REPO" "$WORK_DIR/$clone_name"
            SRC_DIR="$WORK_DIR/$clone_name"
            ;;
        github_release)
            local repo_base="${REPO%.git}"
            local tarball_url
            if type -t release_url_fn &>/dev/null; then
                tarball_url=$(release_url_fn "$repo_base" "$VERSION")
            else
                tarball_url=$(_default_release_url "$repo_base" "$VERSION")
            fi
            local archive_file="$WORK_DIR/${SOFTWARE_NAME}-${VERSION}.tar.gz"
            info "下载 release/tag 版本 ${VERSION}..."
            run wget -q --show-progress -O "$archive_file" "$tarball_url"
            smart_extract "$archive_file" "$WORK_DIR"
            SRC_DIR=$(_find_src_dir "$WORK_DIR")
            ;;
        url)
            info "从 URL 下载: $URL"
            local local_file="$WORK_DIR/$(basename "$URL")"
            run wget -q --show-progress -O "$local_file" "$URL"
            smart_extract "$local_file" "$WORK_DIR"
            SRC_DIR=$(_find_src_dir "$WORK_DIR")
            ;;
        local)
            if [[ -d "$LOCAL_PATH" ]]; then
                SRC_DIR="$LOCAL_PATH"
            elif [[ -f "$LOCAL_PATH" ]]; then
                info "解压本地包: $LOCAL_PATH"
                smart_extract "$LOCAL_PATH" "$WORK_DIR"
                SRC_DIR=$(_find_src_dir "$WORK_DIR")
            else
                error "本地路径不存在: $LOCAL_PATH"
            fi
            ;;
    esac

    # 追加子目录
    if [[ -n "${SRC_SUBDIR:-}" && -n "$SRC_DIR" ]]; then
        SRC_DIR="$SRC_DIR/$SRC_SUBDIR"
    fi

    # dry-run 模式下不验证目录存在性
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] 源码目录: ${SRC_DIR:-<未确定>}"
        return 0
    fi

    [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]] && error "未找到源码目录，请检查源码结构"
    info "源码目录: $SRC_DIR"
}
