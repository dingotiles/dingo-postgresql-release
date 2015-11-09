#!/bin/bash

# USAGE: watch -n1 "./scripts/leaders.sh | sort"

set +e # fail fast
set +x # print commands

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR/..

ETCD_CLUSTER=${ETCD_CLUSTER:-10.244.4.2:4001}

services=$(curl -sL "${ETCD_CLUSTER}/v2/keys/service/?sorted=true" | jq -r ".node.nodes[].key")
for servicekey in ${services[@]}; do
  printf "$(basename $servicekey) "
  membersRaw=$(curl -sL "${ETCD_CLUSTER}/v2/keys${servicekey}/members/?sorted=true" | jq -r ".node.nodes" 2>&1)
  if [[ "${membersRaw}" =~ "null" ]]; then
    echo "deleted"
  else
    members=$(echo $membersRaw | jq -r ".[].value")
    for member in ${members}; do
      # printf "[$member] "
      conn_url=$(echo $member | jq -r .conn_url)
      # matching for "postgres://replicator:replicator@10.244.21.6:32780/postgres"
      regexp="postgres:\/\/([^:]+):([^@]+)@([^:]+):([^\/]+)/([^\/]+)"
      if [[ "${conn_url}" =~ $regexp ]]; then
        host="${BASH_REMATCH[3]}"
        port="${BASH_REMATCH[4]}"
        printf "$(echo $member | jq -r .role)/$(echo $member | jq -r .state)/${host} "
      else
        printf "$(echo $member | jq -r .role)/$(echo $member | jq -r .state)/--- "
      fi
    done
    echo
  fi
done
