#!/bin/bash

# USAGE:
# Run pgbench against current master
#   env $(cat tmp/tutorial.env| xargs) ./images/tutorial/pgbench.sh

if [[ "${ETCD_CLUSTER}X" == "X" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi
PATRONI_SCOPE=${PATRONI_SCOPE:-my_first_cluster}

leader=$(curl -s ${ETCD_CLUSTER}/v2/keys/service/${PATRONI_SCOPE}/leader | jq -r .node.value)
if [[ "${leader}" == "null" ]]; then
  echo "No current leader for cluster"
  exit 1
fi

pg_uri=$(curl -s ${ETCD_CLUSTER}/v2/keys/service/${PATRONI_SCOPE}/members/${leader} | jq -r .node.value | jq -r .conn_url)
if [[ "${pg_uri}X" == "X" || "${pg_uri}" == "null" ]]; then
  echo "Leader ${leader} does not have any member .conn_url data"
  exit 1
fi

pgbench -i ${pg_uri}
pgbench ${pg_uri} -T 20
psql ${pg_uri} -c "select * from pgbench_tellers;"
