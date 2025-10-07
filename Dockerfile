
FROM whyour/qinglong:latest

# 安装必要的依赖
RUN apk add --no-cache python3 py3-pip zstd && \
    pip3 install --no-cache-dir webdavclient3 schedule

# 为 pm2 指定一个可控的、非根目录的主目录
ENV PM2_HOME /ql/.pm2

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

# [最终修复] 解决所有权限问题
# 增加了对 /var/log/nginx 的处理，并确保所有 Nginx 目录都预先创建
RUN mkdir -p /var/lib/nginx/logs /var/lib/nginx/tmp /var/log/nginx && \
    chown -R 1000:1000 \
    /app/backup \
    /ql \
    /etc/nginx \
    /var/lib/nginx \
    /var/log/nginx

# 您需要确保 /app/backup/entrypoint.sh 脚本最后会调用青龙的原始启动命令
CMD ["/app/backup/entrypoint.sh"]
