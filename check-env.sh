#!/bin/bash
# 0 set env
PROJECT="ikube"
BRANCH=master
STAGES=https://raw.githubusercontent.com/humstarman/${PROJECT}-stages/${BRANCH}
SCRIPTS=https://raw.githubusercontent.com/humstarman/${PROJECT}-scripts/${BRANCH}
MANIFESTS=https://raw.githubusercontent.com/humstarman/${PROJECT}-manifests/${BRANCH}
###
#if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - checking environment ... "
# check curl & 
if [ ! -x "$(command -v curl)" ]; then
  if [ -x "$(command -v yum)" ]; then
    yum makecache fast
    yum install -y curl
  fi
  if [ -x "$(command -v apt-get)" ]; then
    apt-get update
    apt-get install -y curl
  fi
fi
curl -s -O $STAGES/version
curl -s $SCRIPTS/check-ansible.sh | /bin/bash
echo $MASTER > ./master.csv
MASTER=$(echo $MASTER | tr "," " ")
#echo $MASTER
N_MASTER=$(echo $MASTER | wc -w)
#echo $N_MASTER
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_MASTER masters: $(cat ./master.csv)."
if [ -z "$NODE" ]; then
  NODE_EXISTENCE=false
else
  NODE_EXISTENCE=true
  echo $NODE > ./node.csv
fi
if $NODE_EXISTENCE; then
  NODE=$(echo $NODE | tr "," " ")
  #echo ${NODE}
  N_NODE=$(echo $NODE | wc -w)
  #echo $N_NODE
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_NODE nodes: $(cat ./node.csv)."
else
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no node to install."
fi
echo $VIP > ./vip.info
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - virtual IP: $(cat ./vip.info)."
echo $PASSWD > ./passwd.log
# mk env file
FILE=info.env
if [ ! -f "$FILE" ]; then
  cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export N_NODE=$N_NODE
export URL=$URL
export VIP=$VIP
EOF
fi
###
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
  curl -s $SCRIPTS/mk-ansible-available.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - connectivity checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - environment checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare to install."
  ## 1 stop selinux
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - shutdown Selinux."
  curl -s -o ./shutdown-selinux.sh $SCRIPTS/shutdown-selinux.sh
  ansible all -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $SCRIPTS/stop-firewall.sh
  ansible all -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $STAGES/batch-mkdir.sh | /bin/bash
###
fi
###

