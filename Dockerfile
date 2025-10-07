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

# [核心修复 502 错误] 强制修改青龙的默认配置文件
# 确保应用监听在本地回环地址(127.0.0.1)，这样 Nginx 才能稳定地找到它
# 这解决了 Nginx 和后端应用之间的通信问题 (502 Bad Gateway)
RUN sed -i 's/IpAddress=0.0.0.0/IpAddress=127.0.0.1/g' /ql/sample/config.sample.sh

# 设置环境变量默认值
ENV SYNC_INTERVAL=600
ENV WEBDAV_URL=""
ENV WEBDAV_BACKUP_PATH=""
ENV WEBDAV_USERNAME=""
ENV WEBDAV_PASSWORD=""
ENV MAX_BACKUPS=10

# 解决所有权限问题
RUN mkdir -p /var/lib/nginx/logs /var/lib/nginx/tmp /var/log/nginx /run/nginx && \
    chown -R 1000:1000 \
    /app/backup \
    /ql \
    /etc/nginx \
    /var/lib/nginx \
    /var/log/nginx \
    /run/nginx

# 您需要确保 /app/backup/entrypoint.sh 脚本最后会调用青龙的原始启动命令
CMD ["/app/backup/entrypoint.sh"]