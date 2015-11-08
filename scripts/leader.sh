#!/bin/bash

# USAGE: watch -n1 "./scripts/leaders.sh | sort"

set +e # fail fast
set +x # print commands

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

internal_service_id=$1
ETCD_CLUSTER=${ETCD_CLUSTER:-10.244.4.2:4001}

if [[ -z "${internal_service_id}" ]]; then
  echo "USAGE: ./scripts/leader.sh <cf-UUID>"
  exit 1
fi

leader_id=$(curl -s ${ETCD_CLUSTER}/v2/keys/service/${internal_service_id}/leader | jq -r .node.value)
if [[ -z "${leader_id}" || "${leader_id}" == "null" ]]; then
  echo "Cluster ${internal_service_id} not found or leader not available yet"
  exit 1
fi

curl -s ${ETCD_CLUSTER}/v2/keys/service/${internal_service_id}/members/${leader_id} | jq -r .node.value | jq -r '.conn_url' | \
  xargs -L1 ./scripts/strip_uri.sh ${internal_service_id}
