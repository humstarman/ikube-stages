#!/bin/bash
show_help () {
cat << USAGE
usage: $0 [ -r RUN-FLAG ] [ -y YEAR ]
use to deploy docker local registry in Kubernetes.

    -i : Specify the IP address of the host where the local registry resides.
    -p : Specify the port of the local registry.
    -c : Specify the cluster IP of the local registry.
    -q : Specify the port used by the cluster ip of the local registry.

This script should run on a Master node.
USAGE
exit 0
}
# Get Opts
while getopts "hi:p:c:q:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    i)  IP=$OPTARG
        ;;
    p)  PORT=$OPTARG
        ;;
    c)  CLUSTER_IP=$OPTARG
        ;;
    q)  CLUSTER_IP_PORT=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
chk_var () {
if [ -z "$2" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no input for \"$1\", try \"$0 -h\"."
  sleep 3
  exit 1
fi
}
[ -z "$*" ] && show_help
chk_var -i $IP
chk_var -p $PORT
chk_var -c $CLUSTER_IP
# 0 set env
COMPONENT="local-registry"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - install ${COMPONENT} ..."
:(){
  FILES=$(find /var/env -name "*.env")
  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:
source info.env
# 1 download 
BASE_PATH=${COMPONENT}
mkdir -p ${BASE_PATH}  
cd ${BASE_PATH} && \
  curl -s -O ${MANIFESTS}/${BASE_PATH}/Makefile.sed && \
  cd -
MANIFESTS_PATH=${COMPONENT}/manifest
mkdir -p ${MANIFESTS_PATH}
cd ${MANIFESTS_PATH} && \
  curl -s -O ${MANIFESTS}/${MANIFESTS_PATH}/endpoint.yaml.sed && \
  curl -s -O ${MANIFESTS}/${MANIFESTS_PATH}/service.yaml.sed && \
  cd -
SCRIPTS_PATH=${COMPONENT}/scripts
mkdir -p ${SCRIPTS_PATH}
cd ${SCRIPTS_PATH} && \
  curl -s -O ${MANIFESTS}/${SCRIPTS_PATH}/mk-ansible-hosts.sh && \
  curl -s -O ${MANIFESTS}/${SCRIPTS_PATH}/rm-ansible-group.sh && \
  curl -s -O ${MANIFESTS}/${SCRIPTS_PATH}/check-docker.sh && \
  chmod +x *.sh && \
  cd -
# 2 sed
cd ${BASE_PATH} && \
  yes | cp Makefile.sed Makefile && \
  sed -i s?"{{.cmd.ip}}"?"${IP}"?g Makefile && \
  sed -i s?"{{.cmd.port}}"?"${PORT}"?g Makefile && \
  sed -i s?"{{.cmd.cluster.ip}}"?"${CLUSTER_IP}"?g Makefile && \
  sed -i s?"{{.cmd.cluster.ip.port}}"?"${CLUSTER_IP_PORT}"?g Makefile && \
  cd - 
# 3 make
cd ${BASE_PATH} && \
  make && \
  cd - 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - ${COMPONENT} installed."
