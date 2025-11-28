FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    HOME=/home/node

# 1. 安装系统依赖 (含全局 PM2)
# 注意：我们这里安装 pm2 -g 是为了保证 pm2-runtime 命令可用
# 但不会在这里安装青龙
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

# 3. 复制控制脚本
COPY starter.py /ql/starter.py

# 4. 权限设置
# 确保 /ql 属于用户 1000，以便后续运行 npm install
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 5. 切换用户
USER 1000

# 6. 端口
EXPOSE 5700

# 7. 启动命令
# 平台扫描不到 package.json，只能执行这个 CMD
CMD ["python3", "/ql/starter.py"]