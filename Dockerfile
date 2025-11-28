# 使用 Node.js 20 (Debian Bullseye)
FROM node:20-bullseye-slim

# 设置环境变量
ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    QL_DIR=/ql \
    QL_DATA_DIR=/ql/data \
    HOME=/home/node \
    # 关键：将 mockbin 加入 PATH 最前端，优先使用我们要创建的假命令
    PATH="/ql/mockbin:$PATH"

# 1. [Root] 安装真实系统依赖
# 我们在这里先把青龙真正需要的 python3, git 等装好
# 这样后面青龙再检查时，虽然 apt-get 是假的，但环境其实已经满足了
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
    procps \
    rclone \
    zstd \
    tar \
    inotify-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 建立 python 软链接
RUN ln -s /usr/bin/python3 /usr/bin/python

# 2. 准备工作目录
WORKDIR /ql

# 3. [Root] 创建“假”的系统管理命令 (核心修复)
# 青龙启动脚本会运行 apt-get update，这里我们创建一个什么都不做直接返回 0 的脚本来骗过它
RUN mkdir -p /ql/mockbin && \
    echo '#!/bin/bash\necho ">> [MOCK] 拦截到 apt-get 调用，跳过系统安装..."\nexit 0' > /ql/mockbin/apt-get && \
    echo '#!/bin/bash\necho ">> [MOCK] 拦截到 apt 调用，跳过系统安装..."\nexit 0' > /ql/mockbin/apt && \
    echo '#!/bin/bash\necho ">> [MOCK] 拦截到 apk 调用，跳过系统安装..."\nexit 0' > /ql/mockbin/apk && \
    echo '#!/bin/bash\necho ">> [MOCK] 拦截到 sudo 调用，直接执行..."\nshift\nexec "$@"' > /ql/mockbin/sudo && \
    chmod +x /ql/mockbin/*

# 复制启动脚本
COPY entrypoint.sh /ql/entrypoint.sh
RUN chmod +x /ql/entrypoint.sh

# 4. [Root] 权限修正
# 确保所有目录归属用户 1000
RUN mkdir -p /ql/data && \
    mkdir -p /home/node/.config/rclone && \
    chown -R 1000:1000 /ql && \
    chown -R 1000:1000 /home/node

# 5. 切换到非 Root 用户
USER 1000

# 6. 安装青龙面板
RUN npm install @whyour/qinglong --save --no-audit --no-fund

# 7. 暴露端口
EXPOSE 5700

# 8. 启动命令
CMD ["/ql/entrypoint.sh"]