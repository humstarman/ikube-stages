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
# 1 generate admin pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate admin pem ... "
mkdir -p ./ssl/admin
FILE=./ssl/admin/admin-csr.json
cat > $FILE << EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
cd ./ssl/admin && \
  cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
    -ca-key=/etc/kubernetes/ssl/ca-key.pem \
    -config=/etc/kubernetes/ssl/ca-config.json \
    -profile=kubernetes admin-csr.json | cfssljson -bare admin && \
  cd -
# 2 distribute admin pem
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - distribute admin pem ... "
ansible ${ANSIBLE_GROUP} -m copy -a "src=./ssl/admin/ dest=/etc/kubernetes/ssl"
# 3 generate kubectl kubeconfig
FILE=mk-kubectl-kubeconfig.sh
cat > $FILE <<"EOF"
#!/bin/bash
:(){
  FILES=$(find /var/env -name "*.env")

  if [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      [ -f $FILE ] && source $FILE
    done
  fi
};:
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER}
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem \
  --token=${BOOTSTRAP_TOKEN}
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin
kubectl config use-context kubernetes
IF0=$(cat /etc/profile | grep "source <(kubectl completion bash)")
if [ -z "$IF0" ]; then
  echo 'source <(kubectl completion bash)' >> /etc/profile
fi
EOF
ansible ${ANSIBLE_GROUP} -m script -a ./mk-kubectl-kubeconfig.sh
