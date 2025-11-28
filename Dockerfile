FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    HOME=/home/node

# 1. 安装系统依赖 (含 PM2 全局安装，方便调用 pm2-runtime)
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

# 3. 复制文件
# 注意：这里不再需要 entrypoint.sh
COPY backup.py /ql/backup.py
COPY ecosystem.config.js /ql/ecosystem.config.js

# 4. 权限修正
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 5. 切换用户
USER 1000

# 6. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

# ================= 核心魔法 =================
# 修改 package.json 的 start 命令
# 1. 配置 Rclone (通过环境变量写入)
# 2. 恢复数据 (backup.py restore)
# 3. 启动 PM2 生态圈 (pm2-runtime start ecosystem.config.js)
# 我们把这些逻辑串联成一行命令，写入 package.json
RUN sed -i 's/"start": ".*"/"start": "mkdir -p ~\/.config\/rclone && echo $RCLONE_CONF_BASE64 | base64 -d > ~\/.config\/rclone\/rclone.conf && python3 \/ql\/backup.py restore && pm2-runtime start ecosystem.config.js"/g' package.json

# 7. 端口
EXPOSE 5700

# 8. 启动命令
# 既然我们修改了 package.json，这里直接用 npm start 即可
# 这样最符合 PaaS 平台的规范
CMD ["npm", "start"]