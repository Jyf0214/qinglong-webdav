#!/bin/sh

echo "=========================================="
echo "QL Panel + WebDAV Auto Backup"
echo "=========================================="

# 检查WebDAV配置
if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_BACKUP_PATH" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
    echo "Warning: WebDAV config incomplete, backup disabled."
    echo "Starting QL panel..."
    # [核心修正] 使用 exec 来让主程序替换当前脚本，成为 PID 1
    exec /docker-entrypoint.sh
else
    echo "WebDAV config detected."
    echo "Backup path: $WEBDAV_BACKUP_PATH"
    echo "Sync interval: ${SYNC_INTERVAL}s"
    echo ""

    # 尝试恢复备份 (前台执行)
    echo "Checking and restoring backup..."
    python3 /app/backup/backup_restore.py restore
    echo "Restore process finished."
    echo ""

    # 启动自动备份服务 (后台执行)
    echo "Starting auto backup service in the background..."
    # [核心修正] 将 *备份* 脚本放到后台运行
    (python3 /app/backup/backup_restore.py) &
    
    # 启动青龙面板 (前台执行)
    echo "Starting QL panel in the foreground..."
    # [核心修正] 使用 exec 来让主程序替换当前脚本，成为 PID 1
    exec /docker-entrypoint.sh
fi