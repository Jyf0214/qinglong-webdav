# 使用一个干净、标准的 Node.js 18 镜像作为基础
FROM node:18-slim

# [核心] 根据您的建议，预先设置青龙需要的环境变量
# QL_DIR 是主目录，QL_DATA_DIR 是所有数据（配置、脚本、日志）的存放位置
ENV QL_DIR=/ql
ENV QL_DATA_DIR=/ql/data

# 设置工作目录
WORKDIR /ql

# 1. 安装系统依赖 (cron 和 python 依然需要)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 2. [核心] 执行您建议的 npm 安装流程
# 一次性安装所有必要的 npm 包
RUN npm install -g pnpm node-pre-gyp @whyour/qinglong

# 3. 创建数据目录
# 确保数据目录存在，以便后续设置权限
RUN mkdir -p /ql/data

# 4. 复制您的自定义备份/恢复脚本
RUN mkdir -p /app/backup
COPY backup_restore.py /app/backup/
COPY entrypoint.sh /app/backup/
RUN chmod +x /app/backup/entrypoint.sh

# 5. [核心] 赋予所有权
# 将整个青龙工作目录和您的脚本目录的所有权赋予 node 用户 (1000)
RUN chown -R 1000:1000 /ql /app

# 6. 切换到非 root 用户
USER 1000

# 7. 设置最终的启动命令
CMD ["/app/backup/entrypoint.sh"]