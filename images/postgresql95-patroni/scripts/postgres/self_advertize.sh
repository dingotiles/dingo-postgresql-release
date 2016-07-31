#!/bin/bash

set +x

if [[ -z "${PATRONI_SCOPE}" ]]; then
  echo "self_advertize.sh: Requires \$PATRONI_SCOPE to write data to etcd"
  exit 0
fi

if [[ -z "${NODE_ID}" ]]; then
  echo "regular_backup.sh: Requires \$NODE_ID to identify itself"
  exit 0
fi

if [[ -z "${ETCD_HOST_PORT}" ]]; then
  echo "regular_backup.sh: Requires \$ETCD_HOST_PORT (host:port) to write data to etcd"
  exit 0
fi

if [[ -z "${CELL_GUID}" ]]; then
  echo "regular_backup.sh: Requires \$CELL_GUID to advertize what cell it is on"
  exit 0
fi

while true; do
  value=$( \
    curl -s localhost:8008 | \
    jq -c \
      --arg cell ${CELL_GUID} \
      --arg node ${NODE_ID} \
      '{cell_guid:$cell, node_id:$node, state:.state, role:.role}' \
    )

  curl -sf ${ETCD_HOST_PORT}/v2/keys/service/${PATRONI_SCOPE}/nodes/${NODE_ID}?ttl=20 \
    -XPUT -d "value=${value}" >/dev/null
  sleep 6
done
