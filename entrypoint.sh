#!/bin/bash

# ================= 配置区域 =================
# Rclone 远程路径 (默认值，可由环境变量覆盖)
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
# 备份文件名
BACKUP_FILENAME="ql_data_backup.tar.zst"
# 目录定义
WORK_DIR="/ql"
DATA_DIR="/ql/data"

# 日志辅助函数
log() { echo -e "[$(date '+%H:%M:%S')] \033[36m[INFO]\033[0m $1"; }
err() { echo -e "[$(date '+%H:%M:%S')] \033[31m[ERROR]\033[0m $1"; }
success() { echo -e "[$(date '+%H:%M:%S')] \033[32m[SUCCESS]\033[0m $1"; }

# ================= 功能函数 =================

# 1. 配置 Rclone
setup_rclone() {
    log "正在配置 Rclone..."
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        # 解码并写入配置文件
        echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
        if [ -s "$HOME/.config/rclone/rclone.conf" ]; then
            success "Rclone 配置文件写入成功"
        else
            err "Rclone 配置文件写入失败 (为空)"
        fi
    else
        err "未找到 RCLONE_CONF_BASE64 环境变量，无法备份/恢复！"
    fi
}

# 2. 恢复数据 (Restore)
restore_data() {
    log "正在检查远程备份: $RCLONE_REMOTE_PATH/$BACKUP_FILENAME"
    
    # 尝试列出文件来检查是否存在
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        log "发现备份文件，开始下载..."
        if rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/ -v; then
            log "下载完成，正在解压 (ZSTD)..."
            
            # 确保数据目录存在
            mkdir -p $DATA_DIR
            
            # 解压：使用 zstd 解压
            if tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR; then
                success "数据恢复成功！"
            else
                err "解压失败！可能是文件损坏。"
            fi
            
            rm -f /tmp/$BACKUP_FILENAME
        else
            err "下载失败！"
        fi
    else
        log "未发现远程备份，将初始化全新环境。"
        # 手动创建必要的子目录，防止监控脚本报错
        mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db $DATA_DIR/log
    fi
}

# 3. 启动青龙面板
start_qinglong() {
    log "正在启动青龙面板..."
    # 启动 Node 进程，不使用 nohup，让日志直接输出到 Docker
    ./node_modules/.bin/qinglong &
    QL_PID=$!
    success "青龙面板已启动 (PID: $QL_PID)"
}

# 4. 监听变动并备份 (Monitor Loop)
start_monitor() {
    # 等待一会，确保青龙完全初始化目录
    sleep 5
    
    # 再次确保监控目录存在
    mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db

    log "启动文件监控 (inotifywait)..."
    log "监控目录: config, scripts, repo, db"
    log "排除目录: log (防止死循环)"

    while true; do
        # 核心命令：阻塞等待文件变动
        # -r: 递归
        # -e: 关注修改、创建、删除、移动
        # --exclude: 极其重要！必须排除日志和临时文件
        inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            --exclude '.*\.git' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db \
            >/dev/null 2>&1
        
        # 当 inotifywait 返回时，说明检测到了变动
        log "⚠️ 检测到文件变更！等待 10s 缓冲..."
        sleep 10
        
        log "⏳ 开始执行备份 (ZSTD Level 18)..."
        
        # 打包命令
        # -I 'zstd -18 -T0': 高压缩比，多线程
        if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data; then
            log "☁️ 正在上传到 OneDrive/Rclone..."
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH" -v; then
                success "✅ 备份上传成功！[$(date)]"
            else
                err "❌ 上传失败！"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            err "❌ 打包失败 (可能内存不足)"
        fi
        
        log "🔄 继续监听文件变动..."
    done
}

# ================= 主流程执行 =================

setup_rclone
restore_data
start_qinglong

# 在后台启动监控循环
start_monitor &
MONITOR_PID=$!

# 捕获 Docker 停止信号，优雅退出
trap "log '正在停止容器...'; kill $QL_PID; kill $MONITOR_PID; exit" SIGINT SIGTERM

# 阻塞主进程，等待青龙退出
wait $QL_PID