# 基础镜像
FROM ghcr.io/jyf0214/qinglong-webdav:latest

# 切换到 root 以便有权限看所有目录
USER root

# 设置 CMD 为列出关键目录
# 我们重点看 /ql 根目录, /ql/docker 目录，以及搜索名为 entrypoint.sh 的文件
CMD echo "===== Listing /ql =====" && ls -la /ql && \
    echo "\n===== Listing /ql/docker =====" && ls -la /ql/docker && \
    echo "\n===== Searching for 'entrypoint' files =====" && find / -name "*entrypoint*" 2>/dev/null