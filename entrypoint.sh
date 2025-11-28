#!/bin/bash

# ================= 配置区域 =================
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
BACKUP_FILENAME="ql_data_backup.tar.zst"
WORK_DIR="/ql"
DATA_DIR="/ql/data"
# 定义 HOME 以防万一
export HOME=/home/1000

log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[INFO]\033[0m $1"; }
err() { echo -e "[$(date '+%H:%M:%S')] \033[31m[ERROR]\033[0m $1"; }
success() { echo -e "[$(date '+%H:%M:%S')] \033[32m[SUCCESS]\033[0m $1"; }

# ================= 核心逻辑 =================

setup_rclone() {
    log "正在配置 Rclone..."
    # 确保目录存在
    mkdir -p "$HOME/.config/rclone"
    
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
        if [ -s "$HOME/.config/rclone/rclone.conf" ]; then
            success "Rclone 配置文件写入成功"
        else
            err "Rclone 配置文件写入失败"
        fi
    else
        err "未找到 RCLONE_CONF_BASE64，跳过备份配置"
    fi
}

restore_data() {
    log "正在检查远程备份..."
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        log "发现备份，开始下载..."
        if rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/ -v; then
            log "下载完成，正在解压 (ZSTD)..."
            # 确保目录存在
            mkdir -p $DATA_DIR
            # 解压
            if tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR; then
                success "数据恢复成功！"
            else
                err "解压失败，文件可能损坏"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            err "下载失败"
        fi
    else
        log "未发现远程备份，将作为全新实例启动。"
        # 手动创建目录防止监控报错
        mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db $DATA_DIR/log
    fi
}

start_monitor() {
    sleep 10
    log "启动文件监控 (inotifywait)..."
    mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db

    while true; do
        # 排除 log, git, swp, tmp
        inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            --exclude '.*\.git' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db \
            >/dev/null 2>&1
        
        log "⚠️ 检测到变动，等待 10s 防抖..."
        sleep 10
        
        log "⏳ 开始打包备份 (ZSTD-18)..."
        # 这里的 -T0 表示使用所有 CPU 核心
        if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data; then
            log "☁️ 正在上传..."
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH" -v; then
                success "✅ 备份完成！[$(date)]"
            else
                err "❌ 上传失败"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            err "❌ 打包失败"
        fi
        
        log "🔄 继续监听..."
    done
}

# ================= 主流程 =================

setup_rclone
restore_data

# 启动监控 (后台)
start_monitor &
MONITOR_PID=$!

log "🚀 准备启动青龙面板..."

# 启动命令逻辑
# 我们尝试查找并执行青龙的启动命令
if command -v qinglong >/dev/null 2>&1; then
    log "使用 'qinglong' 命令启动..."
    qinglong &
    QL_PID=$!
elif [ -f "/ql/docker/docker-entrypoint.sh" ]; then
    log "使用 '/ql/docker/docker-entrypoint.sh' 启动..."
    /ql/docker/docker-entrypoint.sh &
    QL_PID=$!
else
    log "未找到标准启动命令，尝试直接运行 public.js..."
    # 这是一个保底措施，适用于大部分新版青龙
    node /ql/build/public.js &
    QL_PID=$!
fi

# 信号捕获
trap "log 'Stopping...'; kill $QL_PID; kill $MONITOR_PID; exit" SIGINT SIGTERM

# 等待青龙退出
wait $QL_PID