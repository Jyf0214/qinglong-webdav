#!/bin/bash

# ================= 配置区域 =================
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
BACKUP_FILENAME="ql_data_backup.tar.zst"
WORK_DIR="/ql"
DATA_DIR="/ql/data"

# 定义日志输出
log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
err() { echo -e "\033[31m[ERROR] $1\033[0m"; }
success() { echo -e "\033[32m[SUCCESS] $1\033[0m"; }

# 1. 配置 Rclone
setup_rclone() {
    mkdir -p "$HOME/.config/rclone"
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
        if rclone listremotes >/dev/null 2>&1; then
            success "Rclone 配置成功"
        else
            err "Rclone 配置无效，无法备份！"
        fi
    else
        err "未设置 RCLONE_CONF_BASE64，跳过备份配置"
    fi
}

# 2. 恢复数据
restore_data() {
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        log "检测到云端备份，正在恢复..."
        rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/
        # 确保目录存在
        mkdir -p $DATA_DIR
        # 解压
        tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR
        rm -f /tmp/$BACKUP_FILENAME
        success "恢复完成！"
    else
        log "无云端备份，初始化新环境"
        mkdir -p $DATA_DIR/config $DATA_DIR/log $DATA_DIR/db $DATA_DIR/scripts $DATA_DIR/repo
    fi
}

# 3. 监控与备份逻辑 (将在后台运行)
monitor_task() {
    # 延迟 20秒启动，避开青龙启动时的高负载和频繁文件写入
    sleep 20
    
    log "[Backup] 备份服务已就绪 (Inotify 监控中)..."
    
    while true; do
        # 监控变动，排除日志和临时文件
        # 如果 inotifywait 报错（例如目录还没建好），这里会失败，所以加个 || true 防止退出
        inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '/ql/data/deps' \
            --exclude '/ql/data/sys' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db >/dev/null 2>&1

        # 触发变动后
        log "[Backup] 检测到文件变动，等待 10s 防抖..."
        sleep 10
        
        log "[Backup] 开始打包上传 (Level 18)..."
        # 使用 zstd -18 压缩，-T0 多线程
        tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data
        
        if [ $? -eq 0 ]; then
             # 上传，使用 --quiet 减少前台日志干扰，除非出错
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH"; then
                success "[Backup] 备份成功 $(date '+%H:%M:%S')"
            else
                err "[Backup] 上传失败！"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            err "[Backup] 打包失败！"
        fi
        
        # 恢复监听前稍微停顿
        sleep 2
    done
}

# ================= 主执行流程 =================

# 1. 准备环境
setup_rclone
restore_data

# 2. 启动备份进程 (放入后台 &)
# 这一步非常关键：让备份逻辑在后台默默运行，不占用主线程
monitor_task &
BACKUP_PID=$!
log "备份服务后台 PID: $BACKUP_PID"

# 3. 启动青龙 (作为前台主进程)
log "正在启动青龙面板..."

# 捕捉 Docker 停止信号，为了优雅退出后台的备份循环
trap "kill $BACKUP_PID; exit" SIGINT SIGTERM

# 使用 exec 启动青龙，这样青龙就会替代当前 shell 成为 PID 1
# 这会让青龙的日志直接输出到 Docker Logs，并且青龙如果挂了，容器也会重启
exec ./node_modules/.bin/qinglong