#!/bin/sh

echo "=========================================="
echo "QL Panel (NPM Install) + WebDAV Auto Backup"
echo "=========================================="

# 检查WebDAV配置
if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_BACKUP_PATH" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
    echo "Warning: WebDAV config incomplete, backup disabled."
    echo "Starting QL panel..."
    # [核心] 新的启动命令就是 'qinglong'
    exec qinglong
else
    echo "WebDAV config detected."
    
    # 尝试恢复备份 (前台执行)
    echo "Checking and restoring backup..."
    # 注意: 恢复的目标目录现在是 $QL_DATA_DIR (/ql/data)
    python3 /app/backup/backup_restore.py restore
    echo "Restore process finished."
    echo ""

    # 启动自动备份服务 (后台执行)
    echo "Starting auto backup service in the background..."
    (python3 /app/backup/backup_restore.py) &
    
    # 启动青龙面板 (前台执行)
    echo "Starting QL panel in the foreground..."
    # [核心] 使用 exec 来让 'qinglong' 命令成为主进程
    exec qinglong
fi