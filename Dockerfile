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
    # 安装添加外部仓库所需的基础工具
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg && \
    \
    # ---- 正确安装 Node.js 18 的标准流程 ----
    # a. 创建 keyring 目录
    mkdir -p /etc/apt/keyrings && \
    # b. 下载 NodeSource GPG 密钥
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    # c. 添加 NodeSource 的 apt 仓库
    NODE_MAJOR=18 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    # ----------------------------------------
    \
    # 再次更新 apt 缓存以包含新的 NodeSource 仓库
    apt-get update && \
    \
    # 现在安装所有依赖，nodejs 将从 NodeSource 安装
    apt-get install -y --no-install-recommends \
    nodejs \
    git \
    cron \
    python3 \
    python3-pip \
    build-essential && \
    \
    # 清理 apt 缓存，减小镜像体积
    rm -rf /var/lib/apt/lists/*

# 3. 执行您建议的 npm 安装流程 (现在 npm 命令一定存在)
RUN npm install -g pnpm node-pre-gyp @whyour/qinglong

# 4. 创建数据目录
RUN mkdir -p /ql/data

# 5. 复制您的自定义备份/恢复脚本
RUN mkdir -p /app/backup
COPY backup_restore.py /app/backup/
COPY entrypoint.sh /app/backup/
RUN chmod +x /app/backup/entrypoint.sh

# 6. 赋予所有权给 Hugging Face 的运行时用户 (1000)
RUN chown -R 1000:1000 /ql /app

# 7. 切换到非 root 用户
USER 1000

# 8. 设置最终的启动命令
CMD ["/app/backup/entrypoint.sh"]