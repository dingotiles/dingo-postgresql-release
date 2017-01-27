#!/bin/bash

#  env $(cat tmp/tutorial.env| xargs) ./images/tutorial/setup.sh

if [[ "${HOST_IP}X" == "X" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi
if [[ "${DOCKER_SOCK}X" == "X" ]]; then
  echo "Requires \$DOCKER_SOCK"
  exit 1
fi
ETCD_CLUSTER=${HOST_IP}:4001

docker rm -f etcd
docker run -d -p 4001:4001 -p 2380:2380 -p 2379:2379 --name etcd quay.io/coreos/etcd:v2.3.7 \
    -name etcd0 \
    -advertise-client-urls "http://${HOST_IP}:2379,http://${HOST_IP}:4001" \
    -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
    -initial-advertise-peer-urls "http://${HOST_IP}:2380" \
    -listen-peer-urls http://0.0.0.0:2380 \
    -initial-cluster-token etcd-cluster-1 \
    -initial-cluster "etcd0=http://${HOST_IP}:2380" \
    -initial-cluster-state new

docker rm -f registrator
docker run -d --name registrator \
    --net host \
    --volume ${DOCKER_SOCK}:/tmp/docker.sock \
  cfcommunity/registrator:latest /bin/registrator \
    -hostname ${HOST_IP} -ip ${HOST_IP} \
  etcd://${ETCD_CLUSTER}
