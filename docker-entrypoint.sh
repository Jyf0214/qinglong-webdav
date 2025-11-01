#!/bin/bash

dir_shell=/ql/shell
. $dir_shell/share.sh
. $dir_shell/env.sh

log_info() {
  echo -e "======================$1========================\n"
}

handle_error() {
  echo -e "Error: $1"
  exit 1
}

setup_rclone() {
  log_info "写入rclone配置"
  echo "$RCLONE_CONF" > ~/.config/rclone/rclone.conf || handle_error "Failed to write rclone config"
}

configure_nginx() {
  log_info "1. 检测配置文件"
  import_config "$@" || handle_error "Failed to import config"
  make_dir /etc/nginx/conf.d || handle_error "Failed to create /etc/nginx/conf.d"
  make_dir /run/nginx || handle_error "Failed to create /run/nginx"
  init_nginx || handle_error "Failed to initialize nginx"
  fix_config || handle_error "Failed to fix config"
}

install_dependencies() {
  log_info "2. 安装依赖"
  patch_version || handle_error "Failed to patch version"
}

start_nginx() {
  log_info "3. 启动nginx"
  nginx -s reload 2>/dev/null || nginx -c /etc/nginx/nginx.conf || handle_error "Failed to start nginx"
  echo -e "nginx启动成功...\n"
}

start_pm2_services() {
  log_info "4. 启动pm2服务"
  reload_update || handle_error "Failed to reload update"
  reload_pm2 || handle_error "Failed to reload pm2"
}

start_optional_services() {
  if [[ $AutoStartBot == true ]]; then
    log_info "5. 启动bot"
    nohup ql bot >$dir_log/bot.log 2>&1 &
    echo -e "bot后台启动中...\n"
  fi

  if [[ $EnableExtraShell == true ]]; then
    log_info "6. 执行自定义脚本"
    nohup ql extra >$dir_log/extra.log 2>&1 &
    echo -e "自定义脚本后台执行中...\n"
  fi
}

write_login_info() {
  echo -e "##########写入登陆信息############"
  echo "{ \"username\": \"$ADMIN_USERNAME\", \"password\": \"$ADMIN_PASSWORD\" }" > /ql/data/config/auth.json || handle_error "Failed to write auth.json"
}

main() {
  setup_rclone
  configure_nginx
  pm2 l &>/dev/null # This command seems to be a check, not an error, so keeping it as is.
  install_dependencies
  start_nginx
  start_pm2_services
  start_optional_services
  
  echo -e "############################################################\n"
  echo -e "容器启动成功..."
  echo -e "############################################################\n"

  write_login_info

  tail -f /dev/null
  exec "$@"
}

main "$@"
