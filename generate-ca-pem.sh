#!/bin/bash
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
YEAR=10
# 1 download and install CFSSL
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - download CFSSL ... "
source ./version
URL=https://pkg.cfssl.org/$CFSSL_VER
if [[ -f /tmp/cfssl && -f /tmp/cfssljson && -f /tmp/cfssl-certinfo ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL already existed. "
  yes | cp /tmp/cfssl /usr/local/bin/cfssl
  yes | cp /tmp/cfssljson /usr/local/bin/cfssljson
  yes | cp /tmp/cfssl-certinfo /usr/local/bin/cfssl-certinfo
elif [[ -f ./cfssl && -f ./cfssljson && -f ./cfssl-certinfo ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL already existed. "
  yes | cp ./cfssl /usr/local/bin/cfssl
  yes | cp ./cfssljson /usr/local/bin/cfssljson
  yes | cp ./cfssl-certinfo /usr/local/bin/cfssl-certinfo
else
  while true; do
    wget $URL/cfssl_linux-amd64
    chmod +x cfssl_linux-amd64
    mv cfssl_linux-amd64 /usr/local/bin/cfssl
    wget $URL/cfssljson_linux-amd64
    chmod +x cfssljson_linux-amd64
    mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
    wget $URL/cfssl-certinfo_linux-amd64
    chmod +x cfssl-certinfo_linux-amd64
    mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
    if [[ -x "$(command -v cfssl)" && -x "$(command -v cfssljson)" && -x "$(command -v cfssl-certinfo)" ]]; then
      echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CFSSL installed."
      break
    fi
  done
fi
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - generate CA pem ... "
# 2 generate template
mkdir -p ./ssl/ca
cd ./ssl/ca && \
  cfssl print-defaults config > config.json && \
  cfssl print-defaults csr > csr.json && \
  cd -
# 3 generate ca
HOUR=$[8760*${YEAR}]
FILE=./ssl/ca/ca-config.json
cat > $FILE <<EOF
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
cat > $FILE <<EOF
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
exit 0
