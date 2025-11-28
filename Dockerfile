FROM node:20-bullseye-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data

# 1. 安装系统依赖
# 增加了 rclone, zstd, tar
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备目录
WORKDIR /ql
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 3. 预先创建必要的目录并修正权限
# 这一步至关重要，因为无持久盘，目录必须在镜像里建好，并归属于 User 1000
RUN mkdir -p /ql/data && \
    chown -R 1000:1000 /ql

# 4. 切换用户
USER 1000

# 5. 安装青龙
RUN npm install @whyour/qinglong --save --no-audit --no-fund

EXPOSE 5700

CMD ["/ql/entrypoint.sh"]
# 关键步骤：更改目录所有权为 1000
# 即使平台会自动使用 1000 用户运行，文件系统的权限也必须匹配
RUN chown -R 1000:1000 /ql

# 3. [用户阶段] 切换到非 Root 用户
USER 1000

# 4. [用户阶段] 安装青龙面板
# 直接在 /ql 目录下安装
RUN npm install @whyour/qinglong --save --no-audit --no-fund

# 5. [用户阶段] 暴露端口 (青龙默认通常是 5700)
EXPOSE 5700

# 6. 启动命令
CMD ["/ql/entrypoint.sh"]
