# qinglong-webdav
# 青龙面板 + WebDAV 自动备份镜像

基于青龙面板的Docker镜像，支持自动备份数据到WebDAV存储，并在部署/重启时自动恢复。

## ✨ 特性

- 🔄 自动定期备份 `/ql/data` 目录到 WebDAV
- 📦 使用 `tar.zst` 高效压缩备份文件
- 🔁 支持多版本备份，自动清理旧备份
- 🚀 容器重启/重新部署时自动恢复最新备份
- 🌐 支持多平台架构（amd64, arm64）
- 💾 无需持久化卷，所有数据通过 WebDAV 同步

## 📋 前置要求

1. WebDAV 存储服务（如 TeraCloud、坚果云等）
2. 在 WebDAV 中预先创建备份文件夹

## 🚀 快速开始

### 方式一：Docker Run

```bash
docker run -d \
  --name qinglong \
  -p 5700:5700 \
  -e WEBDAV_URL="https://jike.teracloud.jp/dav" \
  -e WEBDAV_BACKUP_PATH="qinglong_backup" \
  -e WEBDAV_USERNAME="your_username" \
  -e WEBDAV_PASSWORD="your_password" \
  -e SYNC_INTERVAL=600 \
  -e MAX_BACKUPS=10 \
  -e TZ=Asia/Shanghai \
  ghcr.io/your-username/qinglong-webdav:latest
```

### 方式二：Docker Compose

创建 `docker-compose.yml`:

```yaml
version: '3'

services:
  qinglong:
    image: ghcr.io/your-username/qinglong-webdav:latest
    container_name: qinglong
    restart: unless-stopped
    ports:
      - "5700:5700"
    environment:
      - WEBDAV_URL=https://jike.teracloud.jp/dav
      - WEBDAV_BACKUP_PATH=qinglong_backup
      - WEBDAV_USERNAME=your_username
      - WEBDAV_PASSWORD=your_password
      - SYNC_INTERVAL=600
      - MAX_BACKUPS=10
      - TZ=Asia/Shanghai
```

启动容器：

```bash
docker-compose up -d
```

## ⚙️ 环境变量配置

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| `WEBDAV_URL` | ✅ | - | WebDAV服务器地址 |
| `WEBDAV_BACKUP_PATH` | ✅ | - | 备份文件夹名（需预先创建） |
| `WEBDAV_USERNAME` | ✅ | - | WebDAV用户名 |
| `WEBDAV_PASSWORD` | ✅ | - | WebDAV密码 |
| `SYNC_INTERVAL` | ❌ | 600 | 备份间隔（秒） |
| `MAX_BACKUPS` | ❌ | 10 | 保留的备份数量 |
| `TZ` | ❌ | UTC | 时区设置 |

## 📦 备份说明

### 备份内容
- 备份 `/ql/data` 目录下的所有内容
- 包括脚本、配置、数据库等

### 备份命名
格式：`qinglong_backup_YYYYMMDD_HHMMSS.tar.zst`

示例：`qinglong_backup_20250106_143022.tar.zst`

### 备份策略
- 容器启动后立即执行首次备份
- 按设定间隔定期自动备份
- 超过 `MAX_BACKUPS` 数量时自动删除最旧的备份

### 恢复机制
- 容器启动时自动检测 `/ql/data` 是否为空
- 如果为空，自动从 WebDAV 下载最新备份并恢复
- 如果不为空，跳过恢复过程

## 🔧 构建镜像

### 本地构建

```bash
docker build -t qinglong-webdav:latest .
```

### 使用 GitHub Actions 自动构建

1. Fork 本仓库
2. 在仓库设置中启用 GitHub Actions
3. 推送代码到 main 分支或创建 tag
4. Actions 将自动构建并推送到 ghcr.io

## 📝 目录结构

```
.
├── Dockerfile                  # Docker镜像定义
├── backup_restore.py           # 备份恢复Python脚本
├── entrypoint.sh              # 容器入口脚本
├── docker-compose.yml         # Docker Compose示例
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions工作流
└── README.md                  # 使用文档
```

## 🔍 常见问题

### 1. 如何查看备份日志？

```bash
docker logs -f qinglong
```

### 2. 如何手动触发备份？

进入容器执行：

```bash
docker exec -it qinglong python3 /app/backup/backup_restore.py
```

### 3. 如何手动恢复备份？

```bash
docker exec -it qinglong python3 /app/backup/backup_restore.py restore
```

### 4. WebDAV 连接失败怎么办？

检查以下内容：
- WebDAV URL 是否正确（需包含 https:// 或 http://）
- 用户名和密码是否正确
- 备份文件夹是否已在网盘中创建
- 网络连接是否正常

### 5. 备份占用空间太大怎么办？

- 增加 `SYNC_INTERVAL` 减少备份频率
- 减少 `MAX_BACKUPS` 保留更少的备份版本
- 定期清理不需要的脚本和日志

## 🌟 支持的 WebDAV 服务

- ✅ TeraCloud (jike.teracloud.jp)
- ✅ 坚果云
- ✅ NextCloud
- ✅ ownCloud
- ✅ 其他标准 WebDAV 服务

## ⚠️ 注意事项

1. **不使用持久化卷**：本镜像设计为无状态部署，所有数据通过 WebDAV 同步
2. **首次启动**：首次启动需要完成青龙面板初始化，之后的重启会自动恢复数据
3. **网络稳定性**：确保容器能稳定访问 WebDAV 服务
4. **备份时间**：大量数据备份可能需要较长时间，建议合理设置备份间隔

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
