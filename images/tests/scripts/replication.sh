#!/bin/bash

set -e

if [[ -z ${TEST_DIR} ]];then
  TEST_DIR=${TEST_VOLUME}/${DELMO_TEST_NAME}
fi

leader_uri=$(cat ${TEST_DIR}/cluster-state.json | jq -r '.leader_uri')

echo Testing replication...
replication_table=$(psql ${leader_uri} -c 'select * from pg_stat_replication;')
echo ${replication_table} | grep '0 rows' && exit 1

echo Replicators have registered with leader

psql ${leader_uri} -c 'DROP TABLE IF EXISTS replication;'
psql ${leader_uri} -c 'CREATE TABLE replication(value text);'
psql ${leader_uri} -c "INSERT INTO replication VALUES ('replication-test');"
psql ${leader_uri} -c 'SELECT value FROM replication;' | grep 'replication-test' || {
  echo Could not store and retrieve value in cluster!
  exit 1
}

cat ${TEST_DIR}/cluster-state.json | jq -r '.uris[]' | while read uri; do
  echo "Testing replication to ${uri}..."
  n=0
  replicating='false'
  for((n=n;n<5;n++)); do
    table=$(psql ${uri} -c 'SELECT value FROM replication;' || echo '')
    if echo ${table} | grep 'replication-test'; then
      replicating='true'
      break
    else
      sleep 1
    fi
  done
  if [[ ${replicating} == 'true' ]]; then
    echo "Cluster replicated after ${n} seconds"
  else
    echo "Cluster is not replicating to ${uri}"
    exit 1
  fi
done

echo "Replication test completed"
