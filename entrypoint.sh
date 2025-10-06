#!/bin/sh

echo "=========================================="
echo "青龙面板 + WebDAV自动备份"
echo "=========================================="

# 检查WebDAV配置
if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_BACKUP_PATH" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
    echo "警告: WebDAV配置不完整，备份功能将不可用"
    echo "请设置以下环境变量:"
    echo "  - WEBDAV_URL"
    echo "  - WEBDAV_BACKUP_PATH"
    echo "  - WEBDAV_USERNAME"
    echo "  - WEBDAV_PASSWORD"
    echo ""
    echo "启动青龙面板（无备份功能）..."
    exec /usr/bin/supervisord -c /etc/supervisord.conf
else
    echo "WebDAV配置已检测到"
    echo "备份路径: $WEBDAV_BACKUP_PATH"
    echo "同步间隔: ${SYNC_INTERVAL}秒"
    echo ""
    
    # 尝试恢复备份
    echo "检查并恢复备份..."
    python3 /app/backup/backup_restore.py restore
    
    echo ""
    echo "启动青龙面板..."
    
    # 启动青龙面板
    /usr/bin/supervisord -c /etc/supervisord.conf &
    
    # 等待青龙面板启动
    sleep 10
    
    # 启动备份服务
    echo "启动自动备份服务..."
    python3 /app/backup/backup_restore.py
fi
