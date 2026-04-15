#!/bin/bash
# ============================================================
# lib/confirm.sh — 参数确认提示
# ============================================================

show_common_params() {
    echo "============================================================"
    echo "  ${SOFTWARE_NAME^^} 编译参数确认"
    echo "============================================================"
    echo "  源码模式:      $SOURCE_MODE"
    case "$SOURCE_MODE" in
        github_clone)   echo "  仓库地址:      $REPO"; echo "  分支:          $BRANCH" ;;
        github_release) echo "  仓库地址:      $REPO"; echo "  版本:          $VERSION" ;;
        url)            echo "  下载地址:      $URL" ;;
        local)          echo "  本地路径:      $LOCAL_PATH" ;;
    esac
    echo "  并行数:        $JOBS"
    echo "  安装目录:      $PREFIX"
    echo "  Dry-run:       $DRY_RUN"
}

prompt_confirm() {
    echo "============================================================"
    if [[ "$YES_TO_ALL" == true ]]; then
        info "已启用 --yes，跳过确认"
        return 0
    fi
    read -rp "是否继续? [Y/n] " _confirm
    case "$_confirm" in
        [nN]*) echo "已取消。"; exit 0 ;;
    esac
}
