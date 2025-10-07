FROM whyour/qinglong:latest

# 安装必要的依赖
RUN apk add --no-cache python3 py3-pip zstd && \
    pip3 install --no-cache-dir webdavclient3 schedule

# [核心修复 1] 为 pm2 指定一个可控的、非根目录的主目录
# 这样 pm2 的所有文件都会被限制在 /ql/.pm2 内
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

# [核心修复 2] 解决所有权限问题
# 将所有运行时需要写入的目录的所有权递归地赋予青龙的标准用户 (UID 568)
# 这必须在所有文件复制和目录创建完成后执行
RUN mkdir -p /var/lib/nginx/tmp && \
    chown -R 568:568 \
    /app/backup \
    /ql \
    /etc/nginx \
    /var/lib/nginx

# CMD ["/app/backup/entrypoint.sh"]  <- 这一行注释掉了，见下方解释