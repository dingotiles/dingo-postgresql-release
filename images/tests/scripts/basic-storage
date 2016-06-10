#!/bin/bash

set -e

if [[ -z ${TEST_DIR} ]];then
  TEST_DIR=${TEST_VOLUME}/${DELMO_TEST_NAME}
fi

uri=$(cat ${TEST_DIR}/cluster-state.json | jq -r '.leader_uri')

echo "Testing basic storage ${uri}..."

psql ${uri} -c 'DROP TABLE IF EXISTS basicstorage;'
psql ${uri} -c 'CREATE TABLE basicstorage(value text);'
psql ${uri} -c "INSERT INTO basicstorage VALUES ('storage-test');"
psql ${uri} -c 'SELECT value FROM basicstorage;' | grep 'storage-test' || {
  echo Could not store and retrieve value in cluster!
  exit 1
}

echo "Running pgbench..."
pgbench -i ${uri}
pgbench ${uri}

echo "Basic Storage is successfull"
