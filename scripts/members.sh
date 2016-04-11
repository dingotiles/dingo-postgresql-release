#!/bin/bash

# USAGE: ./scripts/members.sh UUID

set +e # fail fast
set +x

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

method=$1
ETCD_CLUSTER=${ETCD_CLUSTER:-10.244.4.2:4001}

if [[ -z "${method}" ]]; then
  echo "USAGE: ./scripts/members.sh uuid|cf [uuid|service-name]"
  exit 1
fi
shift

if [[ "$method" == "uuid" ]]; then
  internal_service_id=$1
elif [[ "$method" == "cf" ]]; then
  service_name=$1
  if [[ "${service_name}" == "" ]]; then
    echo "USAGE: ./scripts/members.sh cf service-name"
    exit 1
  fi
  echo Looking up ${service_name}...
  space_guid=$(cat ~/.cf/config.json | jq -r ".SpaceFields.Guid")
  internal_service_id=$(cf curl "/v2/spaces/${space_guid}/service_instances?q=name:${service_name}" | jq -r ".resources[0].metadata.guid")
  echo service-id ${internal_service_id}
else
  echo "USAGE: ./scripts/members.sh uuid|cf UUID"
  exit 1
fi

member_paths=($(curl -s ${ETCD_CLUSTER}/v2/keys/service/${internal_service_id}/members | jq -r ".node.nodes[].key"))
for member_path in "${member_paths[@]}"; do
  role=$(curl -s ${ETCD_CLUSTER}/v2/keys${member_path} | jq -r ".node.value" | jq -r ".role")
  conn_address=$(curl -s ${ETCD_CLUSTER}/v2/keys${member_path} | jq -r ".node.value" | jq -r ".conn_address")
  echo $role $conn_address
done
