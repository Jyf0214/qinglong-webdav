# 使用一个干净、标准的 Node.js 18 镜像作为基础
# 它自带了 node 用户 (UID 1000)，完美契合 Hugging Face 环境
FROM node:18-slim

# 设置工作目录为绝对路径 /ql
WORKDIR /ql

# 1. 安装官方指南要求的所有系统依赖
# pnpm 将通过 npm 安装，所以这里不需要
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    cron \
    python3 \
    python3-pip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 pnpm (青龙面板的核心包管理器)
RUN npm install -g pnpm

# 3. 执行官方的安装脚本
# 下载脚本并执行，这会 git clone 源代码并用 pnpm 安装所有依赖到 /ql 目录
RUN wget -q https://raw.githubusercontent.com/whyour/qinglong/master/install.sh && \
    bash install.sh

# 4. 复制您的自定义备份/恢复脚本
RUN mkdir -p /app/backup
COPY backup_restore.py /app/backup/
COPY entrypoint.sh /app/backup/
RUN chmod +x /app/backup/entrypoint.sh

# 5. [核心] 赋予所有权
# 将整个青龙安装目录和您的脚本目录的所有权赋予 node 用户 (1000)
# 这个 chown 命令范围精确，不会导致构建失败
RUN chown -R 1000:1000 /ql /app

# 6. 切换到非 root 用户
# 明确声明容器的运行时用户是 node (UID 1000)
USER 1000

# 7. 设置最终的启动命令
CMD ["/app/backup/entrypoint.sh"]