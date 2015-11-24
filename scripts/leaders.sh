#!/bin/bash

set +e # fail fast
set +x # print commands

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

ETCD_CLUSTER=${ETCD_CLUSTER:-10.244.4.2:2379}

services=$(curl -s $ETCD_CLUSTER/v2/keys/service | jq -r ".node.nodes[].key")

for service in ${services[@]}; do
  internal_id=$(basename $service)
  ./scripts/leader.sh ${internal_id}
  leader_info=$(./scripts/leader.sh ${internal_id})
done
