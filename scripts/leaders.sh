#!/bin/bash

set +e # fail fast
set +x # print commands

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

if [[ -z "${ETCD_CLUSTER}" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi

services=$(curl -s $ETCD_CLUSTER/v2/keys/serviceinstances | jq -r ".node.nodes[].key")

for service in ${services[@]}; do
  internal_id=$(basename $service)
  ./scripts/leader.sh ${internal_id}
  leader_info=$(./scripts/leader.sh ${internal_id})
done
