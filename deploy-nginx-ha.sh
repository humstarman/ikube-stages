#!/bin/bash
set -e
# 0 set env
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:
FILE=info.env
if [ -f ./$FILE ]; then
  source ./$FILE
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no environment file found!" 
  echo " - exit!"
  sleep 3
  exit 1
fi
# 1 deply HA based on nginx
if ${ONLYNODE_EXISTENCE}; then
  ## generate nginx.conf
  MASTER=$(sed s/","/" "/g ./master.csv)
  DOCKER=$(which docker)
  NGINX_CONF_DIR=/etc/nginx
  FILE=nginx.conf
  cat > $FILE << EOF
error_log stderr notice;

worker_processes auto;
events {
  multi_accept on;
  use epoll;
  worker_connections 1024;
}

stream {
    upstream kube_apiserver {
        least_conn;
EOF
  for ip in $MASTER; do
    cat >> $FILE << EOF
        server $ip:6443;
EOF
  done
  cat >> $FILE << EOF
    }

    server {
        listen        0.0.0.0:6443;
        proxy_pass    kube_apiserver;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}
EOF
  ansible ${ONLY_GROUP} -m shell -a "[ -d "$NGINX_CONF_DIR" ] || mkdir -p "$NGINX_CONF_DIR""
  ansible ${ONLY_GROUP} -m copy -a "src=$FILE dest=$NGINX_CONF_DIR"
  ## generate nginx-proxy.service
  mkdir -p ./systemd-unit
  FILE=./systemd-unit/nginx-proxy.service
  cat > $FILE << EOF
[Unit]
Description=kubernetes apiserver docker wrapper
Wants=docker.socket
After=docker.service

[Service]
User=root
PermissionsStartOnly=true
ExecStart=$DOCKER run -p 6443:6443 \\
          -v $NGINX_CONF_DIR:/etc/nginx \\
          --name nginx-proxy \\
          --network host \\
          --restart on-failure:5 \\
          --memory 512M \\
          nginx:stable
ExecStartPre=-$DOCKER rm -f nginx-proxy
ExecStop=$DOCKER stop nginx-proxy
Restart=always
RestartSec=15s
TimeoutStartSec=30s

[Install]
WantedBy=multi-user.target
EOF
  FILE=${FILE##*/}
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute $FILE ... "
  ansible ${ONLY_GROUP} -m copy -a "src=./systemd-unit/$FILE dest=/etc/systemd/system"
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - start $FILE ... "
  ansible ${ONLY_GROUP} -m shell -a "systemctl daemon-reload"
  ansible ${ONLY_GROUP} -m shell -a "systemctl enable $FILE"
  ansible ${ONLY_GROUP} -m shell -a "systemctl restart $FILE"
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - HA nodes deployed."  
fi
