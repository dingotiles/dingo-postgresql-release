#!/bin/bash

# USAGE: watch -n1 "./scripts/service_instances.sh"

set +e # fail fast
set +x # print commands

# global GUID for "cluster" service plan
SERVICE_PLAN_GUID=${SERVICE_PLAN_GUID:-1545e30e-6dc3-11e5-826a-6c4008a663f0}
ETCD_CLUSTER=${ETCD_CLUSTER:-$ETCD_HOST_PORT}
if [[ -z $ETCD_CLUSTER ]]; then
  echo "Requires \$ETCD_CLUSTER or \$ETCD_HOST_PORT"
  exit 1
fi

cf_target=$(cat ~/.cf/config.json | jq -r .Target)

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

if [[ "$(cf curl /v2/service_plans/${SERVICE_PLAN_GUID}/service_instances | jq -r .error_code)" == "null" ]]; then
  requested_service_instances=($(cf curl /v2/service_plans/${SERVICE_PLAN_GUID}/service_instances | jq -r ".resources[].metadata.guid"))
else
  echo "Service plan ${SERVICE_PLAN_GUID} is not registered on ${cf_target}"
  cf target
  exit 1
fi

running_service_instances=($(curl -s ${ETCD_CLUSTER}/v2/keys/service | jq -r ".node.nodes[].key" | sed -e 's%/service/%%'))

for running in "${running_service_instances[@]}"; do
  found_requested_service_instance=0
  for requested in "${requested_service_instances[@]}"; do
    if [[ $running == $requested ]]; then
      found_requested_service_instance=1
    fi
  done
  if [[ "$found_requested_service_instance" == "0" ]]; then
    echo "Service instance ${running} not requested by ${cf_target} users"
  fi
done
