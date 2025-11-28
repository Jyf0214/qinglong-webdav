import os
import sys
import time
import subprocess
import shutil
from datetime import datetime

# ================= 配置 =================
# 从环境变量读取，或者使用默认值
RCLONE_REMOTE = os.environ.get("RCLONE_REMOTE_PATH", "drive:/ql_backup")
BACKUP_FILE = "ql_data_backup.tar.zst"
LOCAL_ARCHIVE = f"/tmp/{BACKUP_FILE}"
WORK_DIR = "/ql"
DATA_DIR = "/ql/data"

# 需要监控和备份的目录
TARGET_DIRS = [
    f"{DATA_DIR}/config",
    f"{DATA_DIR}/scripts",
    f"{DATA_DIR}/repo",
    f"{DATA_DIR}/db"
]

# 排除列表 (用于 inotifywait)
EXCLUDE_PATTERN = r"(/ql/data/log|/ql/data/deps|.*\.swp|.*\.tmp)"

def log(msg, level="INFO"):
    """打印日志，强制刷新缓冲区以确保 Docker logs 可见"""
    timestamp = datetime.now().strftime('%H:%M:%S')
    color = "\033[32m" if level == "INFO" else "\033[31m"
    reset = "\033[0m"
    print(f"[{timestamp}] {color}[BackupPy]{reset} {msg}", flush=True)

def ensure_dirs():
    """确保必要的目录存在"""
    for d in TARGET_DIRS:
        os.makedirs(d, exist_ok=True)

def run_cmd(cmd, check=True):
    """运行系统命令"""
    try:
        # shell=False 更安全，但需要传入列表
        subprocess.run(cmd, check=check, stdout=sys.stdout, stderr=sys.stderr)
        return True
    except subprocess.CalledProcessError:
        return False

def restore():
    """启动时恢复数据"""
    log("正在检查远程备份...")
    # 检查远程文件是否存在
    check_cmd = ["rclone", "lsf", f"{RCLONE_REMOTE}/{BACKUP_FILE}"]
    result = subprocess.run(check_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    if result.returncode == 0 and result.stdout:
        log("发现备份，开始下载...")
        if run_cmd(["rclone", "copy", f"{RCLONE_REMOTE}/{BACKUP_FILE}", "/tmp/"]):
            log("下载完成，正在解压 (ZSTD)...")
            os.makedirs(DATA_DIR, exist_ok=True)
            # 使用 tar 解压
            if run_cmd(["tar", "-I", "zstd -d", "-xf", LOCAL_ARCHIVE, "-C", WORK_DIR]):
                log("✅ 数据恢复成功")
            else:
                log("❌ 解压失败", "ERROR")
            
            # 清理临时文件
            if os.path.exists(LOCAL_ARCHIVE):
                os.remove(LOCAL_ARCHIVE)
        else:
            log("❌ 下载失败", "ERROR")
    else:
        log("☁️ 远程无备份，初始化全新环境")
        ensure_dirs()
        # 创建 log 目录防止青龙报错
        os.makedirs(f"{DATA_DIR}/log", exist_ok=True)

def perform_backup():
    """执行打包和上传"""
    log("开始打包数据 (ZSTD-18)...")
    
    # 打包命令
    # -cf 创建文件
    # -I zstd 指定压缩程序
    tar_cmd = [
        "tar",
        "-I", "zstd -18 -T0",
        "-cf", LOCAL_ARCHIVE,
        "-C", WORK_DIR,
        "data" # 只打包 data 目录
    ]
    
    if run_cmd(tar_cmd):
        log("打包完成，正在上传到云端...")
        if run_cmd(["rclone", "copy", LOCAL_ARCHIVE, RCLONE_REMOTE]):
            log("🎉 备份上传成功")
        else:
            log("❌ Rclone 上传失败", "ERROR")
        
        # 清理
        if os.path.exists(LOCAL_ARCHIVE):
            os.remove(LOCAL_ARCHIVE)
    else:
        log("❌ 打包失败 (可能内存不足)", "ERROR")

def watch_and_backup():
    """监控文件变动并触发备份"""
    ensure_dirs()
    log("启动文件监控进程...")
    
    while True:
        # 构建 inotifywait 命令
        # 这会阻塞，直到发生变化
        cmd = [
            "inotifywait",
            "-r", # 递归
            "-e", "modify,create,delete,move", # 监听事件
            "--exclude", EXCLUDE_PATTERN
        ] + TARGET_DIRS
        
        # 这里我们将 stdout 重定向到 NULL，因为我们不需要看到具体是哪个文件变了
        # 我们只关心“有东西变了”这个事件
        proc = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        if proc.returncode == 0:
            log("👀 检测到文件变动，等待 10s 防抖...")
            time.sleep(10)
            perform_backup()
            log("继续监控...")
        else:
            log("监控异常 (目录可能被删除)，30s后重试...", "ERROR")
            time.sleep(30)
            ensure_dirs()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == "restore":
            restore()
        elif action == "watch":
            watch_and_backup()
        else:
            print("Usage: python3 backup.py [restore|watch]")
    else:
        print("Usage: python3 backup.py [restore|watch]")