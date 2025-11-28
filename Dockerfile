FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data

# 1. 安装系统依赖
# 新增: inotify-tools (用于监控文件变动)
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备目录
WORKDIR /ql
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 3. 预先创建必要的目录并修正权限
RUN mkdir -p /ql/data && \
    chown -R 1000:1000 /ql

# 4. 切换用户
USER 1000

# 5. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

EXPOSE 5700

CMD ["/ql/entrypoint.sh"]