#!/bin/bash

# =================配置区域=================
# Rclone 远程路径
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"drive:/ql_backup"}
# 备份文件名
BACKUP_FILENAME="ql_data_backup.tar.zst"
# 工作目录
WORK_DIR="/ql"
DATA_DIR="/ql/data"
# =========================================

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
        red "警告：未检测到 RCLONE_CONF_BASE64，将无法备份！"
    fi
}

# 2. 恢复数据
restore_data() {
    green "正在尝试恢复数据..."
    if rclone lsf "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" >/dev/null 2>&1; then
        green "发现备份，正在下载并解压..."
        rclone copy "$RCLONE_REMOTE_PATH/$BACKUP_FILENAME" /tmp/
        
        # 解压
        mkdir -p $DATA_DIR
        tar -I 'zstd -d' -xf /tmp/$BACKUP_FILENAME -C $WORK_DIR
        rm -f /tmp/$BACKUP_FILENAME
        green "恢复完成。"
    else
        yellow "未找到备份，初始化新环境。"
        # 必须手动建立这些目录，否则inotifywait监控不到会报错
        mkdir -p $DATA_DIR/config $DATA_DIR/log $DATA_DIR/db $DATA_DIR/scripts $DATA_DIR/repo
    fi
}

# 3. 启动青龙
start_qinglong() {
    green "启动青龙面板..."
    ./node_modules/.bin/qinglong &
    QL_PID=$!
}

# 4. 监听变动并备份 (核心逻辑)
start_monitor_backup() {
    yellow "启动文件变动监控 (延迟10秒备份, Level 18)..."
    
    # 确保要监控的目录存在
    mkdir -p $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db

    while true; do
        # 等待事件触发
        # -r: 递归监控
        # -e: 只监听 修改、创建、删除、移动
        # --exclude: 极其重要！排除 log 目录和临时文件，防止死循环
        # 监控目标: config, scripts, repo, db (不监控 log 和 deps)
        inotifywait -r \
            -e modify,create,delete,move \
            --exclude '/ql/data/log' \
            --exclude '.*\.swp' \
            --exclude '.*\.tmp' \
            $DATA_DIR/config $DATA_DIR/scripts $DATA_DIR/repo $DATA_DIR/db \
            >/dev/null 2>&1

        # 触发后，进入“防抖”阶段
        yellow "[变动检测] 文件已变更，等待 10s 后备份..."
        sleep 10

        # 执行备份
        green "[备份开始] 正在打包 (ZSTD-18)..."
        
        # 这里的 -18 是压缩等级，-T0 是使用所有CPU核心
        if tar -I 'zstd -18 -T0' -cf /tmp/$BACKUP_FILENAME -C $WORK_DIR data; then
            green "[备份上传] 正在推送到云端..."
            if rclone copy "/tmp/$BACKUP_FILENAME" "$RCLONE_REMOTE_PATH"; then
                green "[备份完成] $(date)"
            else
                red "[备份失败] Rclone 上传出错"
            fi
            rm -f /tmp/$BACKUP_FILENAME
        else
            red "[备份失败] 打包出错 (可能内存不足)"
        fi
        
        green "[监控恢复] 继续监听文件变动..."
    done
}

# ================= 主流程 =================
setup_rclone
restore_data
start_qinglong

# 启动监控循环 (后台)
start_monitor_backup &
MONITOR_PID=$!

trap "kill $QL_PID; kill $MONITOR_PID; exit" SIGINT SIGTERM

wait $QL_PID