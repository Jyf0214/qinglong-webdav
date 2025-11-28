FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
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
COPY backup.py /ql/backup.py

# 3. 权限修正
RUN chmod +x /ql/entrypoint.sh && \
    mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 4. 切换用户
USER 1000

# 5. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

EXPOSE 5700

# ================= 关键修改 =================
# 使用 ENTRYPOINT 强制执行脚本
# 这样即使平台试图运行 npm start，也会作为参数传给我们的脚本（或者直接被忽略）
ENTRYPOINT ["/ql/entrypoint.sh"]