# 使用 Node.js 20 (Debian Bullseye)
FROM node:20-bullseye-slim

# 设置环境变量
ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    # 明确指定 HOME 目录，防止 Rclone 找不到配置文件
    HOME=/home/node

# 1. 安装系统依赖
# 包含：python3 (青龙脚本需要), git, 编译工具, rclone, zstd, inotify-tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    git \
    make \
    g++ \
    gcc \
    curl \
    jq \
    procps \
    rclone \
    zstd \
    tar \
    inotify-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 建立 python 软链接
RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备工作目录
WORKDIR /ql

# 复制启动脚本 (请确保 entrypoint.sh 在同一目录下)
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 3. 权限修正 (关键步骤)
# 预先创建数据目录，并将所有权交给用户 1000
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 4. 切换到非 Root 用户
USER 1000

# 5. 安装青龙面板
# 这一步会下载大量依赖，构建时间较长
RUN npm install @whyour/qinglong --save --no-audit --no-fund

# 6. 暴露端口
EXPOSE 5700

# 7. 启动命令
CMD ["/ql/entrypoint.sh"]