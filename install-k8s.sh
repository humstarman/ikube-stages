#!/bin/bash
set -e
# 0 set env
FILE=info.env
if [ -f ./$FILE ]; then
  source ./$FILE
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no environment file found!" 
  echo " - exit!"
  sleep 3
  exit 1 
fi
source ./version
# 1 download and install Kubernetes 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download kubernetes ... "
#https://dl.k8s.io/v1.11.0/kubernetes-node-linux-amd64.tar.gz
URL=https://dl.k8s.io/$KUBE_VER
FILE=kubernetes-server-linux-amd64.tar.gz
if [ -f "/tmp/$FILE" ]; then
  yes | cp /tmp/${FILE} ./
fi
if [ ! -f "./$FILE" ]; then
  while true; do
    wget $URL/kubernetes-server-linux-amd64.tar.gz && break
  done
fi
if [[ ! -x "$(command -v kubectl)" ]]; then
  while true; do
    # master
    tar -zxvf kubernetes-server-linux-amd64.tar.gz 
    BIN=kube-master-bin
    mkdir -p kubernetes/server/bin/$BIN
    cd kubernetes/server/bin && \
      mv kube-apiserver $BIN && \
      mv kube-controller-manager $BIN && \
      mv kube-scheduler $BIN && \
      cd -
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute Kubernetes master components ... "
    ansible ${MASTER_GROUP} -m copy -a "src=./kubernetes/server/bin/$BIN/ dest=/usr/local/bin mode='a+x'"
    # node
    BIN=kube-node-bin
    mkdir -p kubernetes/server/bin/$BIN
    cd kubernetes/server/bin && \
      mv kubelet $BIN && \
      mv kube-proxy $BIN && \
      mv kubectl $BIN && \
      cd -
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute Kubernetes node components ... "
    ansible ${ANSIBLE_GROUP} -m copy -a "src=./kubernetes/server/bin/$BIN/ dest=/usr/local/bin mode='a+x'"
    if [[ -x "$(command -v kubectl)" ]]; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kubernetes installed."
      break
    fi
  done
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - kubernetes already existed. "
fi
