#!/bin/bash

# ================= 配置区域 =================
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
BACKUP_FILENAME="ql_data_backup.tar.zst"
# 必须使用原镜像定义的路径
ENTRYPOINT_SCRIPT="/ql/docker/docker-entrypoint.sh"

log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[BACKUP-WRAPPER]\033[0m $1"; }
err() { echo -e "[$(date '+%H:%M:%S')] \033[31m[BACKUP-ERROR]\033[0m $1"; }
success() { echo -e "[$(date '+%H:%M:%S')] \033[32m[BACKUP-SUCCESS]\033[0m $1"; }

# ================= 1. 环境准备与恢复 =================

log "初始化 Rclone 配置..."
mkdir -p "$HOME/.config/rclone"
if [ -n "$RCLONE_CONF_BASE64" ]; then
    echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
fi

log "尝试恢复数据 (在青龙启动前)..."
if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
    log "发现云端备份，下载并解压..."
    rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/
    # 确保数据目录存在
    mkdir -p /ql/data
    # 解压覆盖 (zstd)
    tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C /ql
    rm -f /tmp/$BACKUP_FILENAME
    success "数据恢复完成"
else
    log "未发现备份，跳过恢复，使用默认环境"
fi

# ================= 2. 启动后台监控 (核心功能) =================

log "启动后台文件监控 (zstd-18 + 10s防抖)..."

(
    # 在子shell中运行，避免阻塞主进程
    while true; do
        # 等待青龙完全启动后再开始监控，避免启动时的文件写入触发备份
        if [ ! -f "/tmp/ql_monitor_started" ]; then
            sleep 60
            touch /tmp/ql_monitor_started
        fi

        # 确保目录存在
        mkdir -p /ql/data/config /ql/data/scripts /ql/data/repo /ql/data/db

        # 监听变动
        inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            --exclude '.*\.git' \
            /ql/data/config /ql/data/scripts /ql/data/repo /ql/data/db \
            >/dev/null 2>&1
        
        # 防抖 10秒
        sleep 10
        
        # 执行备份
        echo "[BACKUP] 触发备份..."
        if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C /ql data; then
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH"; then
                echo "[BACKUP] 上传成功 $(date)"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        fi
    done
) & 
# 注意上面的 &，这让监控逻辑在后台运行

# ================= 3. 移交控制权 (关键) =================

log "🔥 将控制权移交给原镜像启动脚本: $ENTRYPOINT_SCRIPT"

# 使用 exec，这样原脚本会替换当前进程，PID 保持不变
# 所有的 Nginx 启动、PM2 启动都由原镜像自己处理
exec "$ENTRYPOINT_SCRIPT"