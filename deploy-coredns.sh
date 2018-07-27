#!/bin/bash
COMPONENT=coredns
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - install $COMPONENT ..."
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
BASE_PATH=coredns
mkdir -p ${BASE_PATH}  
cd ${BASE_PATH} && \
  curl -s -O ${MANIFESTS}/${BASE_PATH}/Makefile && \
  curl -s -O ${MANIFESTS}/${BASE_PATH}/coredns.yaml && \
  cd -
# 2 make
cd ${BASE_PATH} && \
  make && \
  cd - 
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] -  $COMPONENT installed."
