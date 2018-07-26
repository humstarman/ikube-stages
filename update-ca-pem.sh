#!/bin/bash
set -e
DEFAULT_YEAR=1
show_help () {
cat << USAGE
usage: $0 [ -g ANSIBLE-GROUP ] [ -y YEAR ]
use to update CA permissons used in Kubernetes.

    -y : Specify the period of validity in term of year.
         If not specified, use "$DEFAULT_YEAR" by default.
    -g : Specify the group of Ansible.
         If not specified, use "all" by default.

This script should run on a Master node.
USAGE
exit 0
}
# Get Opts
while getopts "hy:g:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    y)  YEAR=$OPTARG
        ;;
    g)  ANSIBLE_GROUP=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
ANSIBLE_GROUP=${ANSIBLE_GROUP:-"all"}
YEAR=${YEAR:-"${DEFAULT_YEAR}"}
HOUR=$[8760*${YEAR}]
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - update CA pem ... "
# 1 generate template
mkdir -p ./ssl/ca
cd ./ssl/ca && \
  cfssl print-defaults config > config.json && \
  cfssl print-defaults csr > csr.json && \
  cd -
# 2 generate ca
FILE=./ssl/ca/ca-config.json
cat > $FILE << EOF
{
  "signing": {
    "default": {
      "expiry": "${HOUR}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "${HOUR}h"
      }
    }
  }
}
EOF
FILE=./ssl/ca/ca-csr.json
cat > $FILE << EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
cd ./ssl/ca && \
  cfssl gencert -initca ca-csr.json | cfssljson -bare ca && \
  cd -
# 4 distribute ca pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute CA pem ... "
ansible ${ANSIBLE_GROUP} -m copy -a "src=ssl/ca/ dest=/etc/kubernetes/ssl"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CA pem updated. "
exit 0
