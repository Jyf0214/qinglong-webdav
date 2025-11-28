#!/bin/bash

# ================= 配置 =================
export RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}

# 辅助日志函数
log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[Entrypoint]\033[0m $1"; }
err() { echo -e "[$(date '+%H:%M:%S')] \033[31m[ERROR]\033[0m $1"; }

# 1. 配置 Rclone (Shell 处理 Base64 比较方便，继续保留在这里)
log "正在配置 Rclone..."
mkdir -p "$HOME/.config/rclone"
if [ -n "$RCLONE_CONF_BASE64" ]; then
    echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
    log "Rclone 配置文件已写入"
else
    err "未检测到 RCLONE_CONF_BASE64，备份功能将不可用！"
fi

# 2. 执行恢复 (同步执行，必须等恢复完再启动面板)
log "启动 Python 恢复程序..."
python3 /ql/backup.py restore

# 3. 启动青龙面板 (后台执行)
log "正在启动青龙面板..."
./node_modules/.bin/qinglong &

# 4. 启动备份监控 (后台执行)
# 等待几秒让青龙初始化完基础文件，避免冲突
sleep 10
log "启动 Python 监控程序..."
python3 /ql/backup.py watch &

# 5. 守护进程 (输出日志)
log "接管日志输出..."
# 等待 PM2 启动
sleep 5
# 使用 pm2 logs 保持容器运行并查看日志
./node_modules/.bin/pm2 logs --raw