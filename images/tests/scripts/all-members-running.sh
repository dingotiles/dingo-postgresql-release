#!/bin/bash

set -e

echo "Querying state of cluster members"

curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/cluster/members?recursive=true \
  | jq -r '.node.nodes[].value | fromjson'

curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/cluster/members?recursive=true \
   | jq -r '.node.nodes[].value | fromjson | .state' | while read state; do
  [[ "$state" == "running" ]] || exit 1
done
