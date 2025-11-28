FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    # 显式定义 HOME，确保 rclone 知道去哪里找配置文件
    HOME=/home/node

# 1. 安装系统依赖
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
    rclone \
    zstd \
    tar \
    inotify-tools \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备目录
WORKDIR /ql
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 3. 权限修正
# 关键：确保 /ql 和 /home/node 都归属 1000
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 4. 切换用户
USER 1000

# 5. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

EXPOSE 5700

CMD ["/ql/entrypoint.sh"]