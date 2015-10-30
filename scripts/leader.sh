#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

cf_service_id=$1
etcd_cluster=${etcd_cluster:-10.244.4.2:4001}

if [[ -z "${cf_service_id}" ]]; then
  echo "USAGE: ./scripts/leader.sh <cf-service-uuid>"
  exit 1
fi

internal_id=cf-${cf_service_id}

leader_id=$(curl -s ${etcd_cluster}/v2/keys/service/${internal_id}/leader | jq -r .node.value)
if [[ -z "${leader_id}" || "${leader_id}" == "null" ]]; then
  echo "Cluster ${internal_id} not found or leader not available yet"
  exit 1
fi

curl -s ${etcd_cluster}/v2/keys/service/${internal_id}/members/${leader_id} | jq -r .node.value | jq -r '.conn_url' | \
  xargs -L1 ./scripts/strip_uri.sh
