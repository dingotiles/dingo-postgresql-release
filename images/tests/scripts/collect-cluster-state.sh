#!/bin/bash

if [[ -z ${TEST_DIR} ]];then
  TEST_DIR=${TEST_VOLUME}/${DELMO_TEST_NAME}
fi
mkdir -p ${TEST_DIR}

leader_name=$(etcdctl --endpoint "http://${DOCKER_HOST_IP}:4001" get /service/cluster/leader) || exit 1
leader_uri=$(etcdctl --endpoint "http://${DOCKER_HOST_IP}:4001" get /service/cluster/members/${leader_name} | jq -r '.conn_url') || exit 1

psql ${leader_uri} -c 'SELECT current_database();' || exit 1

curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/cluster/members?recursive=true \
  | jq --arg leader_uri "${leader_uri}" --arg leader_name "${leader_name}" \
  '{uris:[.node.nodes[].value | fromjson | .conn_url], leader_uri:$leader_uri, leader_name:$leader_name }' \
  | tee ${TEST_DIR}/cluster-state.json
