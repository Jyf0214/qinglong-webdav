import os
import sys
import subprocess
import time

# ================= 配置 =================
WORK_DIR = "/ql"
# Rclone 配置
RCLONE_REMOTE = os.environ.get("RCLONE_REMOTE_PATH", "drive:/ql_backup")
BACKUP_FILE = "ql_data_backup.tar.zst"
LOCAL_ARCHIVE = f"/tmp/{BACKUP_FILE}"

def log(msg):
    # 强制刷新缓冲区，确保日志即时显示
    print(f"\033[36m[Starter]\033[0m {msg}", flush=True)

def run_cmd(cmd, shell=True, check=False):
    subprocess.run(cmd, shell=shell, check=check)

def setup_env():
    log("1. 初始化环境变量与 Rclone...")
    if os.environ.get("RCLONE_CONF_BASE64"):
        cmd = "mkdir -p ~/.config/rclone && echo $RCLONE_CONF_BASE64 | base64 -d > ~/.config/rclone/rclone.conf"
        run_cmd(cmd)
    else:
        log("⚠️ 未检测到 Rclone 配置")

def restore_data():
    log("2. 检查并恢复数据...")
    # 检查远程
    res = subprocess.run(f"rclone lsf {RCLONE_REMOTE}/{BACKUP_FILE}", shell=True, stdout=subprocess.PIPE)
    if res.returncode == 0 and res.stdout:
        log("📥 发现备份，下载中...")
        run_cmd(f"rclone copy {RCLONE_REMOTE}/{BACKUP_FILE} /tmp/")
        log("📦 解压数据 (ZSTD)...")
        # 恢复到 /ql
        run_cmd(f"tar -I 'zstd -d' -xf {LOCAL_ARCHIVE} -C {WORK_DIR}")
        run_cmd(f"rm -f {LOCAL_ARCHIVE}")
    else:
        log("✨ 无备份，跳过恢复")

def install_qinglong():
    log("3. ⚡️ 执行运行时安装 (npm install)...")
    
    # 检查是否已经安装过（防止重启容器重复安装浪费时间）
    # 如果 node_modules/@whyour/qinglong 存在，说明已安装
    if os.path.exists(f"{WORK_DIR}/node_modules/@whyour/qinglong"):
        log("✅ 检测到青龙已安装，跳过安装步骤")
        return

    # 【核心需求】启动后安装
    install_cmd = "npm install @whyour/qinglong --save --no-audit --no-fund"
    log(f"执行命令: {install_cmd}")
    
    # 这里必须阻塞等待安装完成
    ret = subprocess.run(install_cmd, shell=True)
    
    if ret.returncode == 0:
        log("✅ 青龙安装完成")
    else:
        log("❌ 安装失败，请检查网络！")
        # 安装失败则退出，让容器重启重试
        sys.exit(1)

def start_pm2():
    log("4. 🚀 启动 PM2 服务...")
    
    # 写入 PM2 配置
    ecosystem = """
module.exports = {
  apps: [
    {
      name: "qinglong",
      script: "./node_modules/.bin/qinglong",
      cwd: "/ql",
      log_date_format: "HH:mm:ss",
    },
    {
      name: "backup-watchdog",
      script: "/ql/starter.py",
      args: "watch",
      interpreter: "python3",
      restart_delay: 5000,
      log_date_format: "HH:mm:ss",
    }
  ]
};
"""
    with open(f"{WORK_DIR}/ecosystem.config.js", "w") as f:
        f.write(ecosystem)

    # 启动 PM2 接管 PID 1
    os.execvp("pm2-runtime", ["pm2-runtime", "start", "ecosystem.config.js"])

def watch_mode():
    """看门狗模式"""
    log("👀 启动文件监控 (Watchdog)...")
    time.sleep(10) # 启动缓冲
    
    dirs = [f"{WORK_DIR}/data/{d}" for d in ["config", "scripts", "repo", "db"]]
    exclude = r"(/ql/data/log|.*\.swp|.*\.tmp)"
    
    # 确保存储目录存在
    for d in dirs:
        os.makedirs(d, exist_ok=True)
    
    while True:
        cmd = f"inotifywait -r -e modify,create,delete,move --exclude '{exclude}' {' '.join(dirs)}"
        res = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        if res.returncode == 0:
            log("📝 文件变动，10秒后备份...")
            time.sleep(10)
            
            log("☁️ 打包上传 (ZSTD-18)...")
            # 只备份 data 目录，不备份 node_modules
            tar_cmd = f"tar -I 'zstd -18 -T0' -cf {LOCAL_ARCHIVE} -C {WORK_DIR} data"
            if subprocess.run(tar_cmd, shell=True).returncode == 0:
                if subprocess.run(f"rclone copy {LOCAL_ARCHIVE} {RCLONE_REMOTE}", shell=True).returncode == 0:
                    log("✅ 备份成功")
                else:
                    log("❌ 上传失败")
                if os.path.exists(LOCAL_ARCHIVE):
                    os.remove(LOCAL_ARCHIVE)
        else:
            time.sleep(10)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "watch":
        watch_mode()
    else:
        # 主启动流程
        setup_env()
        restore_data()
        install_qinglong() # <--- 这里执行安装
        start_pm2()