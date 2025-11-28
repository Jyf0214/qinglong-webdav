# 1. 继承你指定的那个好用的镜像
FROM ghcr.io/jyf0214/qinglong-webdav:latest

# 设置环境
ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    HOME=/home/1000

# 2. [Root] 只安装备份需要的工具
USER root

# 智能判断安装方式 (兼容 Alpine/Debian)
RUN if command -v apk > /dev/null; then \
        apk add --no-cache bash rclone zstd inotify-tools tar curl procps; \
    elif command -v apt-get > /dev/null; then \
        apt-get update && \
        apt-get install -y --no-install-recommends rclone zstd inotify-tools tar curl procps && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# 3. 植入我们的包装脚本
COPY start.sh /ql/start.sh
RUN chmod +x /ql/start.sh

# 4. 权限修正
# 确保 1000 用户有权写入 Rclone 配置和数据目录
# 这步不会破坏原镜像的文件，只是放宽权限
RUN mkdir -p /home/1000/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/1000

# 5. 切换到平台强制的用户
USER 1000

# 6. 入口指向我们的 Wrapper
# 我们的 Wrapper 运行完备份逻辑后，会去调用原镜像的脚本
CMD ["/ql/start.sh"]