#!/bin/sh

echo "=========================================="
echo "QL Panel (Official Install) + WebDAV Auto Backup"
echo "=========================================="

# 切换到青龙的工作目录
cd /ql

# 检查WebDAV配置
if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_BACKUP_PATH" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
    echo "Warning: WebDAV config incomplete, backup disabled."
    echo "Starting QL panel..."
    # [核心] 使用 pm2-runtime 启动，这是官方非 Docker 镜像的正确启动方式
    # 它会读取源代码中的 ecosystem.config.js 文件来启动应用
    exec pm2-runtime start /ql/dist/ecosystem.config.js
else
    echo "WebDAV config detected."
    
    # 尝试恢复备份 (前台执行)
    echo "Checking and restoring backup..."
    python3 /app/backup/backup_restore.py restore
    echo "Restore process finished."
    echo ""

    # 启动自动备份服务 (后台执行)
    echo "Starting auto backup service in the background..."
    (python3 /app/backup/backup_restore.py) &
    
    # 启动青龙面板 (前台执行)
    echo "Starting QL panel in the foreground..."
    # [核心] 使用 exec 和 pm2-runtime 来让主程序成为 PID 1
    exec pm2-runtime start /ql/dist/ecosystem.config.js
fi