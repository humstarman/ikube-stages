#!/bin/bash
FILE=info.env
if [ -f ./$FILE ]; then
  source ./$FILE
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no environment file found!" 
  echo " - exit!"
  sleep 3
  exit 1 
fi
function getScript(){
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
getScript $SCRIPTS deal-env.sh
getScript $SCRIPTS mk-env-conf.sh
getScript $SCRIPTS put-master-ip.sh
getScript $SCRIPTS put-node-ip.sh
NET_ID=$(cat ./master.csv)
NET_ID=${NET_ID%%,*}
NET_ID=${NET_ID%.*}
BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
FILE=k8s.env
cat >/tmp/${FILE} <<"EOF"
BOOTSTRAP_TOKEN="{{.bootstrap.token}}"
SERVICE_CIDR="10.254.0.0/16"
CLUSTER_CIDR="172.30.0.0/16"
NODE_PORT_RANGE="10000-32766"
FLANNEL_ETCD_PREFIX="/kubernetes/network"
CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"
CLUSTER_DNS_SVC_IP="10.254.0.2"
CLUSTER_DNS_DOMAIN="cluster.local."
EOF
sed -i s/"{{.bootstrap.token}}"/"${BOOTSTRAP_TOKEN}"/g /tmp/${FILE}
ansible ${ANSIBLE_GROUP} -m shell -a "mkdir -p /var/env"
ansible ${ANSIBLE_GROUP} -m copy -a "src=/tmp/k8s.env dest=/var/env"
# token
ansible ${ANSIBLE_GROUP} -m shell -a "mkdir -p /etc/kubernetes"
cat >/tmp/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
ansible ${ANSIBLE_GROUP} -m copy -a "src=/tmp/token.csv dest=/etc/kubernetes"
# ip
VIP==${VIP:-"none"}
ansible master -m script -a "./put-master-ip.sh -n $NET_ID -v $VIP"
if $NODE_EXISTENCE; then
  ansible node -m script -a "./put-node-ip.sh -n $NET_ID -v $VIP"
fi
# etcd
NAME=etcd
IPS=$MASTER
N=$(echo $MASTER | wc -w)
NODE_IPS=""
ETCD_NODES=""
ETCD_ENDPOINTS=""
for i in $(seq -s ' ' 1 $N); do
  IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
  NODE_NAME="${NAME}-${IP}"
  NODE_IPS+=" $IP"
  ETCD_NODES+=",${NODE_NAME}=https://$IP:2380"
  ETCD_ENDPOINTS+=",https://$IP:2379"
done
#echo $NODE_IPS
#echo $ETCD_NODES
NODE_IPS=${NODE_IPS#* }
ETCD_NODES=${ETCD_NODES#*,}
ETCD_ENDPOINTS=${ETCD_ENDPOINTS#*,}
#echo $NODE_IPS
#echo $ETCD_NODES
for i in $(seq -s ' ' 1 $N); do
  IP=$(echo $IPS | awk -v j=$i -F ' ' '{print $j}')
  FILE="/tmp/etcd.env.${IP}"
  [ -e $FILE ] && rm -f $FILE
  [ -e $FILE ] || touch $FILE
  NODE_NAME="${NAME}-${IP}"
  cat > $FILE << EOF
export NODE_NAME=$NODE_NAME
export NODE_IPS="$NODE_IPS"
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
  ansible $IP -m copy -a "src=$FILE dest=/var/env/etcd.env"
done
if $NODE_EXISTENCE; then
  FILE="/tmp/etcd.env"
  [ -e $FILE ] && rm -f $FILE
  [ -e $FILE ] || touch $FILE
  cat > $FILE << EOF
export ETCD_NODES=$ETCD_NODES
export ETCD_ENDPOINTS=$ETCD_ENDPOINTS
EOF
  ansible node -m copy -a "src=$FILE dest=/var/env/etcd.env"
fi
ansible ${ANSIBLE_GROUP} -m script -a ./mk-env-conf.sh
cat > ./write-to-etc_profile <<"EOF"
FILES=$(find /var/env -name "*.env")
if [ -n "$FILES" ]
then
  for FILE in $FILES
  do
    [ -f $FILE ] && source $FILE
  done
fi
EOF
ansible ${ANSIBLE_GROUP} -m copy -a "src=./write-to-etc_profile dest=/tmp"
ansible ${ANSIBLE_GROUP} -m script -a ./deal-env.sh
