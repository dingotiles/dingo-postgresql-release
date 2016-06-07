#!/bin/bash

if [[ -z ${TEST_DIR} ]];then
  TEST_DIR=${TEST_STATE}/${DELMO_TEST_NAME}
fi
mkdir -p ${TEST_DIR}

leader_name=$(etcdctl --endpoint "http://${DOCKER_HOST_IP}:4001" get /service/cluster/leader) || exit 1
uri=$(etcdctl --endpoint "http://${DOCKER_HOST_IP}:4001" get /service/cluster/members/${leader_name} | jq -r '.conn_url') || exit 1
psql ${uri} -c 'SELECT current_database();' || exit 1
echo writting ${uri} to ${TEST_DIR}
echo ${uri} > ${TEST_DIR}/leader_con
