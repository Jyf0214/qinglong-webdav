#!/bin/bash

# 开启调试模式，打印执行的每一行命令（排查完后可注释掉）
# set -x

# ================= 配置区域 =================
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
BACKUP_FILENAME="ql_data_backup.tar.zst"
WORK_DIR="/ql"
DATA_DIR="/ql/data"

# 定义日志输出函数
log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
err() { echo -e "\033[31m[ERROR] $1\033[0m"; }
success() { echo -e "\033[32m[SUCCESS] $1\033[0m"; }

# 0. 环境检查
log "环境初始化检查..."
log "当前用户 ID: $(id -u)"
log "当前 Home 目录: $HOME"
log "Rclone 目标路径: $RCLONE_REMOTE_PATH"

# 1. 配置 Rclone & 测试连接
setup_rclone() {
    # 确保 config 目录存在
    mkdir -p "$HOME/.config/rclone"
    
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        log "正在写入 Rclone 配置文件..."
        echo "$RCLONE_CONF_BASE64" | base64 -d > "$HOME/.config/rclone/rclone.conf"
        
        # 调试：检查配置文件是否存在
        if [ -s "$HOME/.config/rclone/rclone.conf" ]; then
            success "配置文件写入成功。"
        else
            err "配置文件写入失败或为空！"
        fi

        # 关键调试：测试 Rclone 是否能列出远程配置
        log "正在测试 Rclone 连接 (listremotes)..."
        if rclone listremotes; then
            success "Rclone 连接测试通过！"
        else
            err "Rclone 连接失败！请检查 RCLONE_CONF_BASE64 是否正确。"
            # 如果连接失败，不退出，但要在日志里看到
        fi
    else
        err "未检测到 RCLONE_CONF_BASE64 环境变量！备份功能将不可用。"
    fi
}

# 2. 恢复数据
restore_data() {
    log "检查远程是否存在备份文件: $BACKUP_FILENAME ..."
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        log "发现备份，开始下载..."
        if rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/ -v; then
            log "下载完成，正在解压 (ZSTD)..."
            # 确保目录存在
            mkdir -p $DATA_DIR
            # 解压并覆盖
            tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR
            rm -f /tmp/$BACKUP_FILENAME
            success "数据恢复成功！"
        else
            err "下载备份文件失败！"
        fi
    else
        log "远程未找到备份文件，初始化全新环境。"
        # 必须手动创建目录，否则 inotifywait 会报错
        mkdir -p $DATA_DIR/config $DATA_DIR/log $DATA_DIR/db $DATA_DIR/scripts $DATA_DIR/repo
    fi
}

# 3. 启动青龙
start_qinglong() {
    log "正在启动青龙面板..."
    # 移除后台运行的静默模式，直接让它输出日志
    # 这里不需要 nohup，因为 Docker 会捕获 stdout
    ./node_modules/.bin/qinglong &
    QL_PID=$!
    log "青龙 PID: $QL_PID"
}

# 4. 监听变动并备份
start_monitor_backup() {
    # 等待几秒确保目录都建立好了
    sleep 5
    
    log "启动文件监控进程 (inotifywait)..."
    
    # 确保监控目录绝对存在
    mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db

    while true; do
        log "正在监听文件变动..."
        
        # 去掉 >/dev/null 以便在日志中看到报错
        # 如果这里报错，循环会疯狂打印日志，所以如果报错我们会 sleep 一下
        if inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db; then
            
            log "检测到变动！等待 10s 防抖..."
            sleep 10
            
            log "开始打包备份..."
            if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data; then
                log "打包完成，正在上传..."
                # 使用 -v 显示上传进度日志
                if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH" -v; then
                    success "备份上传成功！"
                else
                    err "Rclone 上传失败！"
                fi
                rm -f /tmp/$BACKUP_FILENAME
            else
                err "打包失败（可能是内存不足或磁盘空间不足）"
            fi
        else
            err "inotifywait 异常退出！可能监控目录不存在。休眠 30s 重试..."
            sleep 30
        fi
    done
}

# ================= 主流程 =================
setup_rclone
restore_data
start_qinglong

# 启动监控 (后台)
start_monitor_backup &
MONITOR_PID=$!

# 捕获信号
trap "log '接收到停止信号'; kill $QL_PID; kill $MONITOR_PID; exit" SIGINT SIGTERM

# 等待青龙主进程
wait $QL_PID