#!/bin/sh

echo "=========================================="
echo "QL Panel + WebDAV Auto Backup"
echo "=========================================="

# 检查WebDAV配置
if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_BACKUP_PATH" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
    echo "Warning: WebDAV config incomplete, backup disabled"
    echo "Required environment variables:"
    echo "  - WEBDAV_URL"
    echo "  - WEBDAV_BACKUP_PATH"
    echo "  - WEBDAV_USERNAME"
    echo "  - WEBDAV_PASSWORD"
    echo ""
    echo "Starting QL panel (no backup)..."
    exec /docker-entrypoint.sh
else
    echo "WebDAV config detected"
    echo "Backup path: $WEBDAV_BACKUP_PATH"
    echo "Sync interval: ${SYNC_INTERVAL}s"
    echo ""
    
    # 尝试恢复备份
    echo "Checking and restoring backup..."
    python3 /app/backup/backup_restore.py restore
    
    echo ""
    echo "Starting QL panel..."
    
    # 启动青龙面板（使用原始入口点）
    /docker-entrypoint.sh &
    
    # 等待面板启动
    sleep 15
    
    # 启动备份服务
    echo "Starting auto backup service..."
    python3 /app/backup/backup_restore.py
fi
