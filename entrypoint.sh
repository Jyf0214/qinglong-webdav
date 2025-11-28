#!/bin/bash

# =================配置区域=================
# 默认备份间隔：3600秒 (1小时)
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
# Rclone 远程路径 (例如: gdrive:/qinglong_backup)
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
# 备份文件名
BACKUP_FILENAME="ql_data_backup.tar.zst"
# 工作目录
WORK_DIR="/ql"
DATA_DIR="/ql/data"
# =========================================

# 颜色输出
green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }
red(){ echo -e "\033[31m\033[01m$1\033[0m"; }

# 1. 配置 Rclone
setup_rclone() {
    mkdir -p ~/.config/rclone
    if [ -n "$RCLONE_CONF_BASE64" ]; then
        green "检测到 Rclone 配置，正在写入..."
        echo "$RCLONE_CONF_BASE64" | base64 -d > ~/.config/rclone/rclone.conf
    else
        red "未检测到 RCLONE_CONF_BASE64 环境变量，无法进行备份和恢复！"
        # 如果没有配置，我们依然允许程序运行，但数据会丢失
    fi
}

# 2. 恢复数据 (Restore)
restore_data() {
    green "正在尝试从远程存储恢复数据..."
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        green "发现备份文件，开始下载..."
        rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/
        
        green "正在解压备份 (ZSTD Level 21)..."
        # 使用 zstd 解压
        # 确保目录存在
        mkdir -p $DATA_DIR
        tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR
        
        green "数据恢复完成！"
        rm -f /tmp/$BACKUP_FILENAME
    else
        yellow "远程未找到备份文件，将作为全新实例启动。"
        # 初始化必要的空目录结构
        mkdir -p $DATA_DIR/config $DATA_DIR/log $DATA_DIR/db $DATA_DIR/scripts $DATA_DIR/repo
    fi
}

# 3. 启动青龙 (后台运行)
start_qinglong() {
    green "启动青龙面板..."
    # 以后台方式启动，并把日志输出到标准输出
    ./node_modules/.bin/qinglong &
    QL_PID=$!
}

# 4. 定时备份循环 (Backup Loop)
start_backup_loop() {
    yellow "启动定时备份服务，间隔: ${BACKUP_INTERVAL}秒"
    while true; do
        sleep "$BACKUP_INTERVAL"
        
        green "[备份开始] 正在打包数据..."
        # tar 打包 /ql/data 目录
        # -I 'zstd -21 -T0' : 使用 zstd 21级压缩，-T0 表示使用所有CPU核心加速
        # 注意：21级压缩非常耗内存，如果你的容器内存小于1G，可能会崩溃。
        # 如果崩溃，请把 -21 改为 -19 或更低。
        if tar -I 'zstd -21 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data; then
            green "[备份上传] 正在上传到 Rclone..."
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH"; then
                green "[备份成功] $(date)"
            else
                red "[备份失败] 上传失败！"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            red "[备份失败] 打包失败（可能是内存不足）"
        fi
    done
}

# ================= 主流程 =================
setup_rclone
restore_data
start_qinglong

# 启动备份循环（放在后台）
start_backup_loop &
BACKUP_PID=$!

# 捕获信号，优雅退出
trap "kill $QL_PID; kill $BACKUP_PID; exit" SIGINT SIGTERM

# 等待青龙进程结束（保持容器运行）
wait $QL_PID
