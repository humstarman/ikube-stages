#!/bin/bash
# 0 set env
FILE=info.env
source ./${FILE}
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart Kubernetes componenets ..."
COMPONENTS="etcd"
[[ "flannel" == "${CNI}" ]]  && COMPONENTS+=" flanneld"
COMPONENTS+=" kube-apiserver kube-controller-manager kube-scheduler docker kubelet kube-proxy"
MASTER_COMPONENTS="etcd kube-apiserver kube-controller-manager kube-scheduler"
GROUP="${ANSIBLE_GROUP}"
# 1 stop svc
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop $COMPONENT ..."
  if echo $MASTER_COMPONENTS | grep $COMPONENT > /dev/null 2>&1; then
    GROUP="master"
  else
    GROUP="${ANSIBLE_GROUP}"
  fi
  ansible $GROUP -m shell -a "systemctl stop $COMPONENT"
done
# 2 start svc
ansible $GROUP -m shell -a "systemctl daemon-reload"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - restart $COMPONENT ..."
  if echo $MASTER_COMPONENTS | grep $COMPONENT > /dev/null 2>&1; then
    GROUP="master"
  else
    GROUP="${ANSIBLE_GROUP}"
  fi
  ansible $GROUP -m shell -a "systemctl restart $COMPONENT"
done
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes componenets restarted."
exit 0
