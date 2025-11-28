#!/bin/bash

# ================= 配置区域 =================
export RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
PM2_CMD="./node_modules/.bin/pm2"

# 辅助日志
log() { echo -e "[Entrypoint] $1"; }

# 1. Rclone 配置 (同步执行)
log "正在初始化配置..."
mkdir -p "$HOME/.config/rclone"
if [ -n "$RCLONE_CONF_BASE64" ]; then
    echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
    log "Rclone 配置已写入"
else
    echo "⚠️ 未找到 RCLONE_CONF_BASE64，将无法备份"
fi

# 2. 数据恢复 (同步执行 - 必须在面板启动前完成)
log "正在检查并恢复数据..."
python3 /ql/backup.py restore

# 3. 启动青龙 (后台执行)
# 注意：这里加 & 是为了不让它阻塞脚本，我们需要在它启动后插入我们的进程
log "正在启动青龙面板..."
./node_modules/.bin/qinglong &
QL_PID=$!

# 4. 等待 PM2 服务就绪 (关键步骤)
# 我们循环检查 pm2 是否活过来了
log "等待 PM2 服务启动..."
while ! $PM2_CMD ping > /dev/null 2>&1; do
    sleep 1
done
log "PM2 服务已在线！"

# 5. 【核心修改】将备份脚本注入 PM2
# 这样备份脚本的日志就会出现在 pm2 logs 中，且拥有进程守护能力
log "正在将备份监控挂载到 PM2..."
$PM2_CMD start /ql/backup.py \
    --name "backup-watchdog" \
    --interpreter python3 \
    --restart-delay 5000 \
    -- watch

# 6. 接管日志
# --raw 保持原始颜色输出
log "所有服务已启动，开始输出日志..."
$PM2_CMD logs --raw