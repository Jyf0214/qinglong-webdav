#!/bin/bash
set -e

# 定义工作目录
WORK_DIR="/ql"

echo "Checking environment..."

# 确保基础配置文件存在 (如果挂载了存储卷，这步很重要)
# 如果是第一次运行，我们可能需要从 node_modules 里复制默认配置（如果有的话）
# 这里我们做最基础的目录结构检查
mkdir -p $WORK_DIR/data/config
mkdir -p $WORK_DIR/data/log
mkdir -p $WORK_DIR/data/db
mkdir -p $WORK_DIR/data/scripts
mkdir -p $WORK_DIR/data/repo

# 设置一些环境变量，确保青龙知道自己在哪里运行
export QL_DIR=$WORK_DIR
export QL_DATA_DIR=$WORK_DIR/data

echo "Starting Qinglong Panel..."

# 青龙的 npm 包安装后，可执行文件通常在 node_modules/.bin/qinglong
# 使用 exec 启动让进程接管 PID 1，方便接收停止信号
# 这里的 'start' 是假设 qinglong cli 的启动命令，通常直接运行即可
exec ./node_modules/.bin/qinglong
