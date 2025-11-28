FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    HOME=/home/node

# 1. 安装系统依赖
# 必须包含 inotify-tools 供 python subprocess 调用
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

# 2. 准备工作目录
WORKDIR /ql

# 3. 复制脚本
COPY entrypoint.sh /ql/entrypoint.sh
COPY backup.py /ql/backup.py

# 4. 设置权限
RUN chmod +x /ql/entrypoint.sh && \
    mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 5. 切换用户
USER 1000

# 6. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

EXPOSE 5700

CMD ["/ql/entrypoint.sh"]