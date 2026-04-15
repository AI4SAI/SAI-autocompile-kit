#!/bin/bash
# ============================================================
# lib/modules.sh — module load 封装
# ============================================================

# 插件设置 MODULES 变量（空格分隔的模块列表）

load_modules() {
    if [[ -z "${MODULES:-}" ]]; then
        info "无需加载模块"
        return 0
    fi

    info "加载系统模块: $MODULES"
    source /etc/profile.d/modules.sh 2>/dev/null || true
    module purge 2>/dev/null || true
    for mod in $MODULES; do
        module load "$mod" || error "无法加载模块: $mod"
    done
    info "已加载模块: $(module list 2>&1 | tail -1)"
}
