# 1. 使用一个稳定、完整的 Ubuntu LTS 镜像作为基础
FROM ubuntu:22.04

# 设置环境变量，防止 apt-get 在构建时出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置青龙需要的环境变量
ENV QL_DIR=/ql
ENV QL_DATA_DIR=/ql/data

# 设置工作目录
WORKDIR /ql

# 2. 安装所有系统依赖并正确设置 Node.js 18 仓库
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=18 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs \
    git \
    cron \
    python3 \
    build-essential && \
    rm -rf /var/lib/apt/lists/*

# 3. [核心] 安装 rclone
# 使用官方脚本安装最新版本的 rclone
RUN curl https://rclone.org/install.sh | bash

# 4. 安装 npm 依赖，分步进行
RUN npm install -g pnpm node-pre-gyp
RUN npm install -g @whyour/qinglong

# 5. 复制您的自定义 rclone 备份/恢复脚本
# 注意：我们不再需要 backup_restore.py 了
RUN mkdir -p /app/backup
COPY entrypoint.sh /app/backup/
RUN chmod +x /app/backup/entrypoint.sh

# 6. 赋予所有权给 Hugging Face 的运行时用户 (1000)
RUN chown -R 1000:1000 /ql /app

# 7. 切换到非 root 用户
USER 1000

# 8. 设置最终的启动命令
CMD ["/app/backup/entrypoint.sh"]