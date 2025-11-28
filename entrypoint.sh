#!/bin/bash

# ================= 配置区域 =================
export RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}

# 辅助日志
log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[Debug-Entry]\033[0m $1"; }

# 1. 配置 Rclone
log "正在配置 Rclone..."
mkdir -p "$HOME/.config/rclone"
if [ -n "$RCLONE_CONF_BASE64" ]; then
    echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
    log "Rclone 配置文件写入完成"
else
    log "❌ 警告: 未找到 RCLONE_CONF_BASE64"
fi

# 2. 执行恢复
log "----------------------------------------"
log "STEP 1: 执行恢复程序 (Python)"
log "----------------------------------------"
# 直接在前台运行，如果有报错会直接显示
python3 /ql/backup.py restore

# 3. 启动监控 (前台运行)
log "----------------------------------------"
log "STEP 2: 启动监控程序 (Python)"
log "----------------------------------------"
log "⚠️ 注意：当前模式下不会启动青龙面板，仅测试备份功能！"
log "正在启动 watch 循环..."

# 这里不加 &，让它直接霸占前台，这样容器就不会退出，你也能看到所有日志
python3 /ql/backup.py watch