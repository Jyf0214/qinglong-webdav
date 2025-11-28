module.exports = {
  apps: [
    {
      name: "qinglong",
      script: "./node_modules/.bin/qinglong",
      // 青龙的输出不需要前缀，直接输出
      log_date_format: "HH:mm:ss",
    },
    {
      name: "backup-watchdog",
      script: "/ql/backup.py",
      args: "watch",
      interpreter: "python3",
      // 如果脚本崩了，5秒后重启
      restart_delay: 5000,
      // 开启日志时间戳
      log_date_format: "HH:mm:ss",
    },
  ],
};