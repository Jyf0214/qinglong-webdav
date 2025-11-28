# 1. 使用你指定的镜像作为基础
FROM ghcr.io/jyf0214/qinglong-webdav:latest

# 设置环境变量
ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    # 明确指定 HOME，防止 Rclone 找不到配置
    HOME=/home/1000

# 2. [Root] 安装备份所需的工具
# 这里的逻辑是：先试 apk (Alpine)，如果失败就试 apt-get (Debian/Ubuntu)
# 这样无论这个基础镜像是哪个版本都能兼容
USER root
RUN if command -v apk > /dev/null; then \
        echo "Detected Alpine Linux"; \
        apk add --no-cache bash rclone zstd inotify-tools tar curl procps; \
    elif command -v apt-get > /dev/null; then \
        echo "Detected Debian/Ubuntu"; \
        apt-get update && \
        apt-get install -y --no-install-recommends rclone zstd inotify-tools tar curl procps && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Error: Unknown package manager"; exit 1; \
    fi

# 3. 准备工作目录
WORKDIR /ql

# 复制我们的启动脚本
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 4. [关键] 权限修正
# 你的平台强制用 1000 用户，所以必须把 /ql 和 home 目录都给 1000
# 同时创建必要的配置目录，防止 Rclone 报错
RUN mkdir -p /ql/data && \
    mkdir -p /home/1000/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/1000

# 5. 切换到用户 1000 (模拟你的部署平台环境)
USER 1000

# 6. 暴露端口
EXPOSE 5700

# 7. 启动命令指向我们的脚本
CMD ["/ql/entrypoint.sh"]