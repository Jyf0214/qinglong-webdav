#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import time
import subprocess
import schedule
from datetime import datetime
from webdav3.client import Client

class QinglongBackup:
    def __init__(self):
        self.webdav_url = os.getenv('WEBDAV_URL', '')
        self.backup_path = os.getenv('WEBDAV_BACKUP_PATH', '')
        self.username = os.getenv('WEBDAV_USERNAME', '')
        self.password = os.getenv('WEBDAV_PASSWORD', '')
        self.sync_interval = int(os.getenv('SYNC_INTERVAL', '600'))
        self.max_backups = int(os.getenv('MAX_BACKUPS', '10'))
        self.data_dir = '/ql/data'
        self.backup_dir = '/tmp/backups'
        
        if not all([self.webdav_url, self.backup_path, self.username, self.password]):
            print("ERROR: WebDAV config incomplete!")
            print(f"WEBDAV_URL: {bool(self.webdav_url)}")
            print(f"WEBDAV_BACKUP_PATH: {bool(self.backup_path)}")
            print(f"WEBDAV_USERNAME: {bool(self.username)}")
            print(f"WEBDAV_PASSWORD: {bool(self.password)}")
            sys.exit(1)
        
        # 确保备份目录存在
        os.makedirs(self.backup_dir, exist_ok=True)
        
        # 配置WebDAV客户端
        self.client = Client({
            'webdav_hostname': self.webdav_url,
            'webdav_login': self.username,
            'webdav_password': self.password
        })
        
        # 确保远程备份目录存在
        try:
            if not self.client.check(self.backup_path):
                self.client.mkdir(self.backup_path)
                print(f"Created remote directory: {self.backup_path}")
        except Exception as e:
            print(f"Failed to check/create remote directory: {e}")
            print(f"Please ensure '{self.backup_path}' exists in your WebDAV storage")
    
    def create_backup(self):
        """创建备份并上传到WebDAV"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_filename = f"qinglong_backup_{timestamp}.tar.zst"
            backup_filepath = os.path.join(self.backup_dir, backup_filename)
            
            print(f"[{datetime.now()}] Creating backup...")
            
            # 使用tar和zstd压缩数据目录
            cmd = f"tar -I zstd -cf {backup_filepath} -C {self.data_dir} ."
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"Backup creation failed: {result.stderr}")
                return False
            
            # 获取文件大小
            size_mb = os.path.getsize(backup_filepath) / (1024 * 1024)
            print(f"Backup file created: {backup_filename} ({size_mb:.2f} MB)")
            
            # 上传到WebDAV
            remote_path = f"{self.backup_path}/{backup_filename}"
            print(f"Uploading to: {remote_path}")
            
            self.client.upload_sync(remote_path=remote_path, local_path=backup_filepath)
            print(f"Upload successful!")
            
            # 删除本地备份文件
            os.remove(backup_filepath)
            
            # 清理旧备份
            self.cleanup_old_backups()
            
            return True
            
        except Exception as e:
            print(f"Backup failed: {e}")
            return False
    
    def cleanup_old_backups(self):
        """删除超过指定数量的旧备份"""
        try:
            # 获取所有备份文件
            files = self.client.list(self.backup_path)
            backup_files = [f for f in files if f.startswith('qinglong_backup_') and f.endswith('.tar.zst')]
            backup_files.sort(reverse=True)
            
            # 删除超过保留数量的备份
            if len(backup_files) > self.max_backups:
                for old_backup in backup_files[self.max_backups:]:
                    remote_path = f"{self.backup_path}/{old_backup}"
                    self.client.clean(remote_path)
                    print(f"Deleted old backup: {old_backup}")
                    
        except Exception as e:
            print(f"Failed to cleanup old backups: {e}")
    
    def restore_backup(self):
        """从WebDAV恢复最新备份"""
        try:
            print(f"[{datetime.now()}] Checking if restore needed...")
            
            # 检查是否存在关键文件来判断是否需要恢复
            # 青龙的关键目录：config, scripts, db 等
            key_paths = [
                os.path.join(self.data_dir, 'config', 'auth.json'),
                os.path.join(self.data_dir, 'db', 'database.sqlite'),
                os.path.join(self.data_dir, 'config', 'config.sh')
            ]
            
            has_data = any(os.path.exists(path) for path in key_paths)
            
            if has_data:
                print("Existing data detected, skip restore")
                return True
            
            # 获取最新备份
            files = self.client.list(self.backup_path)
            backup_files = [f for f in files if f.startswith('qinglong_backup_') and f.endswith('.tar.zst')]
            
            if not backup_files:
                print("No backup found, skip restore")
                return True
            
            backup_files.sort(reverse=True)
            latest_backup = backup_files[0]
            
            print(f"Found latest backup: {latest_backup}")
            
            # 下载备份文件
            remote_path = f"{self.backup_path}/{latest_backup}"
            local_path = os.path.join(self.backup_dir, latest_backup)
            
            print("Downloading backup...")
            self.client.download_sync(remote_path=remote_path, local_path=local_path)
            
            size_mb = os.path.getsize(local_path) / (1024 * 1024)
            print(f"Download completed ({size_mb:.2f} MB)")
            
            # 确保数据目录存在
            os.makedirs(self.data_dir, exist_ok=True)
            
            # 解压备份
            print("Restoring data...")
            cmd = f"tar -I zstd -xf {local_path} -C {self.data_dir}"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"Restore failed: {result.stderr}")
                return False
            
            print("Data restored successfully!")
            
            # 删除临时文件
            os.remove(local_path)
            
            return True
            
        except Exception as e:
            print(f"Failed to restore backup: {e}")
            return False
    
    def run_backup_loop(self):
        """运行定期备份循环"""
        print(f"Backup service started, interval: {self.sync_interval}s")
        
        # 立即执行一次备份
        self.create_backup()
        
        # 设置定期备份
        schedule.every(self.sync_interval).seconds.do(self.create_backup)
        
        while True:
            schedule.run_pending()
            time.sleep(1)

if __name__ == '__main__':
    backup = QinglongBackup()
    
    # 根据参数决定执行恢复还是备份
    if len(sys.argv) > 1 and sys.argv[1] == 'restore':
        backup.restore_backup()
    else:
        backup.run_backup_loop()
