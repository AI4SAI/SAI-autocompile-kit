#!/bin/bash
# ============================================================
# lib/envscript.sh — 生成 env 脚本 + 渲染 slurm 模板
# ============================================================

# 插件可设置:
#   ENV_EXTRAS=()                  — 额外的环境设置行
#   ENV_PATH_PREPEND=()            — 需要 prepend 到 PATH 的目录
#   ENV_LD_LIBRARY_PATH_PREPEND=() — 需要 prepend 到 LD_LIBRARY_PATH 的目录
#   BUILD_TYPE="compiled"          — "compiled" 或 "python"
#   VENV_DIR=""                    — Python venv 路径 (BUILD_TYPE=python 时)

# ---------- 生成 env 脚本 ----------
generate_env_script() {
    ENV_SCRIPT_PATH="$PREFIX/${SOFTWARE_NAME}_env.sh"

    {
        echo "#!/bin/bash"
        echo "# ${SOFTWARE_NAME^^} 环境设置脚本 (自动生成)"

        if [[ "${BUILD_TYPE:-compiled}" == "python" ]]; then
            # Python 包：激活 base conda env
            if [[ -n "${BASE_ENV:-}" ]]; then
                echo "source \"${BASE_ENV}\""
            fi
        else
            # 编译型：加载 modules
            if [[ -n "${MODULES:-}" ]]; then
                echo "source /etc/profile.d/modules.sh 2>/dev/null || true"
                echo "module purge 2>/dev/null || true"
                echo "for mod in $MODULES; do"
                echo '    module load "$mod"'
                echo "done"
            fi
        fi

        # 插件自定义行
        for line in "${ENV_EXTRAS[@]+"${ENV_EXTRAS[@]}"}"; do
            echo "$line"
        done

        # 插件声明的 PATH
        for p in "${ENV_PATH_PREPEND[@]+"${ENV_PATH_PREPEND[@]}"}"; do
            echo "export PATH=\"${p}:\${PATH}\""
        done

        # 插件声明的 LD_LIBRARY_PATH
        for p in "${ENV_LD_LIBRARY_PATH_PREPEND[@]+"${ENV_LD_LIBRARY_PATH_PREPEND[@]}"}"; do
            echo "export LD_LIBRARY_PATH=\"${p}:\${LD_LIBRARY_PATH}\""
        done
    } > "$ENV_SCRIPT_PATH"

    chmod +x "$ENV_SCRIPT_PATH"
    info "已生成环境脚本: $ENV_SCRIPT_PATH"
}

# ---------- 渲染 slurm 模板 ----------
generate_slurm_script() {
    local template="${SCRIPT_DIR}/slurm_template/${SOFTWARE_NAME}.slurm"
    if [[ ! -f "$template" ]]; then
        warn "未找到 slurm 模板: $template，跳过"
        return 0
    fi

    local slurm_script="$PREFIX/${SOFTWARE_NAME}.slurm"
    sed "s|{{ENV_SCRIPT}}|${ENV_SCRIPT_PATH}|g" "$template" > "$slurm_script"
    chmod +x "$slurm_script"
    info "已生成 slurm 提交脚本: $slurm_script"
}

# ---------- 统一入口 ----------
generate_scripts() {
    generate_env_script
    generate_slurm_script
}
