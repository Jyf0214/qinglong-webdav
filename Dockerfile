# 使用 Node.js LTS (Bullseye slim 版本体积较小且兼容性好)
FROM node:20-bullseye-slim

# 设置环境变量
ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data

# 1. [Root阶段] 安装系统级依赖
# 青龙脚本和依赖通常需要 Python3, Git, Make, g++ 等
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 为 python3 建立软链接 (有些脚本只认 python)
RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. [Root阶段] 准备目录和权限
# 创建工作目录
WORKDIR /ql

# 复制启动脚本到镜像中
COPY entrypoint.sh /ql/entrypoint.sh

# 赋予脚本执行权限
RUN chmod +x /ql/entrypoint.sh

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
