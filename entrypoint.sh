#!/bin/bash

# ================= 配置区域 =================
# Rclone 远程路径
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
# 备份文件名
BACKUP_FILENAME="ql_data_backup.tar.zst"
# 目录定义
WORK_DIR="/ql"
DATA_DIR="/ql/data"

# ================= 日志函数 =================
# 将日志直接打印到 PID 1 的标准输出，确保 Docker logs 能看到
log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[Backup-System]\033[0m $1" > /proc/1/fd/1; }
err() { echo -e "[$(date '+%H:%M:%S')] \033[31m[ERROR]\033[0m $1" > /proc/1/fd/1; }

# ================= 核心逻辑 =================

# 1. 配置 Rclone
setup_rclone() {
    mkdir -p "$HOME/.config/rclone"
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
        log "Rclone 配置已注入"
    else
        err "警告: 未找到 RCLONE_CONF_BASE64，无法备份！"
    fi
}

# 2. 恢复数据
restore_data() {
    log "检查云端备份文件..."
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        log "发现备份，正在下载..."
        rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/
        log "正在解压 (ZSTD)..."
        mkdir -p $DATA_DIR
        tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR
        rm -f /tmp/$BACKUP_FILENAME
        log "恢复完成！"
    else
        log "云端无备份，初始化全新环境"
        mkdir -p $DATA_DIR/config $DATA_DIR/log $DATA_DIR/db $DATA_DIR/scripts $DATA_DIR/repo
    fi
}

# 3. 监控与备份主进程 (后台运行)
run_monitor_backup() {
    # 等待 15秒，让青龙先完成初始化和目录创建
    sleep 15
    
    log "监控进程启动 (inotifywait)..."
    
    # 确保目录存在，否则 inotifywait 会直接退出
    mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db

    while true; do
        # 监听变动
        # 注意：这里去掉了 -m (monitor) 改用默认阻塞模式，变化一次后退出 wait，执行备份，再循环
        # 排除 log 目录防止死循环
        if inotifywait -r -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '/ql/data/deps' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db >/dev/null 2>&1; then
            
            log "检测到文件变动！等待 10秒防抖..."
            sleep 10
            
            log "开始打包数据 (ZSTD-18)..."
            # 为了防止打包失败导致数据丢失，先打包到临时文件
            if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data >/dev/null 2>&1; then
                log "打包完成，正在上传到 OneDrive..."
                if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH"; then
                    log "🎉 备份上传成功！"
                else
                    err "上传失败，请检查网络或 Rclone 配置"
                fi
                rm -f /tmp/$BACKUP_FILENAME
            else
                err "打包失败 (可能是内存不足)"
            fi
        else
            # 如果 inotifywait 报错(比如目录被删了)，休眠一下重建目录
            err "监控异常 (目录可能不存在)，30秒后重试..."
            sleep 30
            mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db
        fi
    done
}

# ================= 主执行流程 =================

echo "--- 初始化环境 ---"
setup_rclone
restore_data

echo "--- 启动备份监控 (后台) ---"
# 重点：在这里加 & 放到后台，这样它就不会被青龙阻塞
run_monitor_backup &
BACKUP_PID=$!

echo "--- 启动青龙面板 ---"
# 启动青龙 (它会启动 PM2)
./node_modules/.bin/qinglong

echo "--- 容器守护中 ---"
# 青龙启动完 PM2 后可能会结束当前命令
# 我们需要一个命令来阻塞住容器，不让它退出，同时输出日志
# 我们监控 PM2 的日志，这样既能保活，又能看到青龙的报错

# 等待 PM2 准备好
sleep 5

# 最终命令：显示 PM2 日志
./node_modules/.bin/pm2 logs --raw