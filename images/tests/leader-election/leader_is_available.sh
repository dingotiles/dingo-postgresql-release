#!/bin/bash

leader_name=$(etcdctl --endpoint "http://$HOST_IP:4001" get /service/cluster/leader) || exit 1
uri=$(etcdctl --endpoint "http://$HOST_IP:4001" get /service/cluster/members/${leader_name} | jq -r '.conn_url') || exit 1
psql ${uri} -c 'SELECT current_database();' || exit 1
echo ${uri} > ${TEST_DIR}/leader_con
