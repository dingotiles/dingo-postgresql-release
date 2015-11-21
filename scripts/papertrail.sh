#!/bin/bash

set -e # fail fast

# Displays all the logs for a specific CF service instance
# https://papertrailapp.com/groups/688143/events?q=(a65aebfc-3e73-419b-b50c-bdc0110136a1+OR+8e8f0540-8719-4d2a-9f2a-ffc02cb892dd)&r=604849041863630862-604849149376266257

BASE_PAPERTRAIL=${BASE_PAPERTRAIL:-https://papertrailapp.com/groups/688143}
ETCD_CLUSTER=${ETCD_CLUSTER:-10.244.4.2:4001}

service_name=$1
if [[ -z $service_name ]]; then
  >&2 echo "USAGE: papertrail.sh <service-name>"
  exit 1
fi

if [[ ! -f ~/.cf/config.json ]]; then
  >&2 echo "Login to target Cloud Foundry first"
  exit 1
fi

space_guid=$(cat ~/.cf/config.json | jq -r .SpaceFields.Guid)
if [[ -z $space_guid ]]; then
  >&2 echo "Target org/space first"
  exit 1
fi

function fetch_org_space {
  export space_name=$(cf curl "/v2/spaces/${space_guid}" | jq -r ".entity.name")
  export organization_guid=$(cf curl "/v2/spaces/${space_guid}" | jq -r ".entity.organization_guid")
  export org_name=$(cf curl "/v2/organizations/${organization_guid}" | jq -r ".entity.name")
}

service_guid=$(cf curl "/v2/spaces/${space_guid}/service_instances?q=name:${service_name}" | jq -r ".resources[0].metadata.guid")
if [[ "${service_guid}" == "null" ]]; then
  fetch_org_space
  >&2 echo "Service ${service_name} not available in org ${org_name} / space ${space_name}"
  exit 1
fi

any_guids=${service_guid}
backend_instance_paths=$(curl -s ${ETCD_CLUSTER}/v2/keys/serviceinstances/${service_guid}/nodes | jq -r ".node.nodes[].key")
for backend_instance_path in ${backend_instance_paths[@]}; do
  regexp="nodes\/(.*)"
  if [[ $backend_instance_path =~ $regexp ]]; then
    backend_guid="${BASH_REMATCH[1]}"
    any_guids="${any_guids}+OR+${backend_guid}"
  else
    >&2 echo "no match for ${backend_instance_path}"
  fi
done

echo "${BASE_PAPERTRAIL}/events?q=(${any_guids})"
