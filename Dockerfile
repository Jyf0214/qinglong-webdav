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
    && npm install -g pm2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备目录
WORKDIR /ql

# 3. 复制唯一的脚本
COPY starter.py /ql/starter.py

# 4. 【特洛伊木马】将青龙安装到隐藏目录
# 这样 /ql 目录下除了 starter.py 啥都没有
# 平台检测不到 package.json，就不会运行 npm start
WORKDIR /ql_hidden
RUN npm install @whyour/qinglong --save --no-audit --no-fund

# 5. 权限和清理
WORKDIR /ql
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    # 确保 /ql 下没有 package.json
    rm -f /ql/package.json && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /ql_hidden && \
    chown -R 1000:1000 /home/node

# 6. 切换用户
USER 1000

# 7. 端口
EXPOSE 5700

# 8. 启动命令
# 直接运行我们的 Python 脚本
# 因为没有 package.json，平台会尊重这个 CMD
CMD ["python3", "/ql/starter.py"]