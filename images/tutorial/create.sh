#!/bin/bash

# USAGE:
# Create container without wal-e archives, where tmp/tutorial.env containers required args:
#   env $(cat tmp/tutorial.env| xargs) ./images/tutorial/create.sh
# Create container with wal-e archives, where tmp/tutorial-wale.env is passed to docker container
#   env_file=tmp/tutorial-wale.env env $(cat tmp/tutorial.env| xargs) ./images/tutorial/create.sh

if [[ "${ETCD_CLUSTER}X" == "X" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi
if [[ "${HOST_IP}X" == "X" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi
if [[ "${POSTGRES_USERNAME}X" == "X" ]]; then
  echo "Requires \$POSTGRES_USERNAME"
  exit 1
fi
if [[ "${POSTGRES_PASSWORD}X" == "X" ]]; then
  echo "Requires \$POSTGRES_PASSWORD"
  exit 1
fi
if [[ "${POSTGRESQL_IMAGE}X" == "X" ]]; then
  echo "Requires \$POSTGRESQL_IMAGE"
  exit 1
fi

DOCKER_OPTS=${DOCKER_OPTS:-}
PATRONI_SCOPE=${PATRONI_SCOPE:-my_first_cluster}

beatle=${beatle:-john}
public_port=${public_port:-40000}
if [[ "${beatle}" == "paul" ]]; then
  public_port=40001
fi
env_file=${env_file:-/tmp/empty}
if [[ ! -f $env_file ]]; then
  touch $env_file
fi

docker rm -f ${beatle}
docker run -d ${DOCKER_OPTS} \
    --name ${beatle} -p ${public_port}:5432 \
    --env-file=${env_file} \
    -e NAME=${beatle} \
    -e PATRONI_SCOPE=${PATRONI_SCOPE} \
    -e "ETCD_HOST_PORT=${ETCD_CLUSTER}" \
    -e "DOCKER_HOSTNAME=${HOST_IP}" \
    -e "POSTGRES_USERNAME=${POSTGRES_USERNAME}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    ${POSTGRESQL_IMAGE}
docker logs -f ${beatle}
