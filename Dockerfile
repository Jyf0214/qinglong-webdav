#!/bin/sh

# 设置青龙的工作目录
cd /ql

# 检查 rclone 配置
if [ -z "$RCLONE_CONF_BASE64" ] || [ -z "$BACKUP_REMOTE_PATH" ]; then
    echo "警告：未提供 RCLONE_CONF_BASE64 或 BACKUP_REMOTE_PATH。自动备份/恢复功能禁用。" >&2
    echo "启动青龙面板..."
    exec qinglong
fi

RCLONE_CONFIG_PATH="/tmp/rclone.conf"
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 创建有效的 rclone 配置文件。" >&2
    exec qinglong
fi

# 青龙的数据目录是由环境变量 QL_DATA_DIR 定义的
DATA_DIR=${QL_DATA_DIR:-"/ql/data"}
VERSIONS_PATH="${BACKUP_REMOTE_PATH}/versions"

echo "确保远程备份目录 ${VERSIONS_PATH} 存在..."
rclone --config "$RCLONE_CONFIG_PATH" mkdir "${VERSIONS_PATH}"

# 1. 启动时恢复
if [ "$(echo "$RESTORE_ON_STARTUP" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
    echo "检测到 RESTORE_ON_STARTUP=true，正在查找最新的备份进行恢复..."
    LATEST_VERSION_DIR=$(rclone --config "$RCLONE_CONFIG_PATH" lsf -F p --dirs-only "${VERSIONS_PATH}/" | sort -r | head -n 1)

    if [ -z "$LATEST_VERSION_DIR" ]; then
        echo "未在远程找到任何可用的备份版本。将使用一个空的 data 目录启动。"
    else
        echo "找到最新备份版本: ${LATEST_VERSION_DIR}，开始恢复到 ${DATA_DIR}..."
        rclone --config "$RCLONE_CONFIG_PATH" sync -v "${VERSIONS_PATH}/${LATEST_VERSION_DIR}" "${DATA_DIR}"
        echo "恢复完成。"
    fi
fi

# 2. 启动自动备份服务 (后台)
echo "启动自动备份服务于后台..."
(
    BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
    MAX_BACKUPS=${MAX_BACKUPS:-10}
    echo "备份任务已启动，每 ${BACKUP_INTERVAL} 秒一次，保留最多 ${MAX_BACKUPS} 个版本。"

    while true; do
        sleep "$BACKUP_INTERVAL"
        TIMESTAMP=$(date +"%Y-%m-%dT%H-%M-%S")
        CURRENT_BACKUP_PATH="${VERSIONS_PATH}/${TIMESTAMP}"
        
        echo "[备份任务 ${TIMESTAMP}] 开始备份到 ${CURRENT_BACKUP_PATH}"
        rclone --config "$RCLONE_CONFIG_PATH" copy -v "${DATA_DIR}" "${CURRENT_BACKUP_PATH}"
        
        DIRS_TO_PURGE=$(rclone --config "$RCLONE_CONFIG_PATH" lsf -F p --dirs-only "${VERSIONS_PATH}/" | sort | head -n -$MAX_BACKUPS)
        for dir in $DIRS_TO_PURGE; do
            if [ -n "$dir" ]; then
                echo "[备份任务 ${TIMESTAMP}] 清理旧版本: ${dir}"
                rclone --config "$RCLONE_CONFIG_PATH" purge "${VERSIONS_PATH}/${dir}"
            fi
        done
        echo "[备份任务 ${TIMESTAMP}] 备份和清理完成。"
    done
) &

# 3. 启动青龙面板 (前台)
echo "启动青龙面板于前台..."
exec qinglong