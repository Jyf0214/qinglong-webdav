FROM whyour/qinglong:latest

# 安装必要的依赖
RUN apk add --no-cache python3 py3-pip zstd && \
    pip3 install --no-cache-dir webdavclient3 schedule

# 创建备份脚本目录
RUN mkdir -p /app/backup

# 复制备份和恢复脚本
COPY backup_restore.py /app/backup/
COPY entrypoint.sh /app/backup/

# 设置执行权限
RUN chmod +x /app/backup/entrypoint.sh

# 设置环境变量默认值
ENV SYNC_INTERVAL=600
ENV WEBDAV_URL=""
ENV WEBDAV_BACKUP_PATH=""
ENV WEBDAV_USERNAME=""
ENV WEBDAV_PASSWORD=""
ENV MAX_BACKUPS=10

# [核心修复] 解决权限问题
# 将脚本目录和青龙数据目录的所有权递归地赋予一个通用的非 root 用户 (UID 1000)
# 这必须在所有文件复制和目录创建完成后执行
RUN chown -R 1000:1000 /app/backup /ql/data

# 使用自定义入口点（不覆盖原有的 ENTRYPOINT）
CMD ["/app/backup/entrypoint.sh"]
