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

# [终极修复] 根据您的提议，对所有应用可能触及的目录进行全面授权
# 这可以彻底解决任何隐藏的、在启动后才触发的权限问题，从而解决 502 错误
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx && \
    chown -R 1000:1000 \
    /app \
    /ql \
    /etc \
    /var \
    /run

# 您需要确保 /app/backup/entrypoint.sh 脚本最后会调用青龙的原始启动命令
CMD ["/app/backup/entrypoint.sh"]