#!/bin/sh

# 检查 HTTP_PORT 环境变量
if [ -n "$HTTP_PORT" ]; then
  # 使用 sed 修改 nginx.conf 文件中的监听端口
  sed -i "s/listen 80;/listen $HTTP_PORT;/" /etc/nginx/nginx.conf
fi

# 执行 nginx
exec "$@"
