# 1. 使用一个稳定、完整的 Ubuntu LTS 镜像作为基础
FROM ubuntu:22.04

# 设置环境变量，防止 apt-get 在构建时出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置青龙需要的环境变量
ENV QL_DIR=/ql
ENV QL_DATA_DIR=/ql/data

# 设置工作目录
WORKDIR /ql

# 2. 安装所有系统依赖
# 包括: ca-certificates, curl, gnupg 用于添加 NodeSource 仓库
# nodejs: 我们需要的 Node.js 运行时
# build-essential: 用于编译原生 npm 模块
# git: 解决 "git error occurred" 的关键
# python3, pip, cron: 青龙的其他依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    nodejs \
    git \
    cron \
    python3 \
    python3-pip \
    build-essential && \
    # 清理 apt 缓存，减小镜像体积
    rm -rf /var/lib/apt/lists/*

# 3. 执行您建议的 npm 安装流程
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