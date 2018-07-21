#!/bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - install calico ..."
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
source info.env
# 1 download 
BASE_PATH=calico
mkdir -p ${BASE_PATH}  
cd ${BASE_PATH} && \
  curl -s -O ${MANIFESTS}/${BASE_PATH}/Makefile.sed && \
  cd -
MANIFESTS_PATH=calico/manifest
mkdir -p ${MANIFESTS_PATH}
cd ${MANIFESTS_PATH} && \
  curl -s -O ${MANIFESTS}/${MANIFESTS_PATH}/calico.yaml.sed && \
  curl -s -O ${MANIFESTS}/${MANIFESTS_PATH}/rbac.yaml.sed && \
  cd -
# 2 sed
cd ${BASE_PATH} && \
  yes | cp Makefile.sed Makefile && \
  sed -i s?"{{.env.cluster.cidr}}"?"${CLUSTER_CIDR}"?g Makefile && \
  cd - 
# 3 make
cd ${BASE_PATH} && \
  make && \
  cd - 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - calico installed."
