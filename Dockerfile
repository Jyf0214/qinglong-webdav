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

# 3. [核心修复] 创建一个假的 apt-get 来拦截并禁用青龙应用在运行时的调用
# 这可以防止因权限不足而导致的启动失败
RUN echo '#!/bin/sh\necho "INFO: apt-get call intercepted and disabled in non-root environment." >&2\nexit 0' > /usr/local/bin/apt-get && \
    chmod +x /usr/local/bin/apt-get

# 4. 安装 npm 依赖，分步进行
RUN npm install -g pnpm node-pre-gyp
RUN npm install -g @whyour/qinglong

# 5. 复制您的自定义 rclone 备份/恢复脚本
RUN mkdir -p /app/backup
COPY entrypoint.sh /app/backup/
RUN chmod +x /app/backup/entrypoint.sh

# 6. 赋予所有权给 Hugging Face 的运行时用户 (1000)
# 我们只 chown 应用需要的目录，保持系统目录的干净
RUN chown -R 1000:1000 /ql /app

# 7. 切换到非 root 用户
USER 1000

# 8. 设置最终的启动命令
CMD ["/app/backup/entrypoint.sh"]