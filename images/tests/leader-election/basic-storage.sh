#!/bin/bash

if [[ -z ${TEST_DIR} ]];then
  TEST_DIR=${TEST_VOLUME}/${DELMO_TEST_NAME}
fi

uri=$(cat ${TEST_DIR}/leader_con)
echo Testing basic storage "$uri"

psql ${uri} -c 'DROP TABLE IF EXISTS sanitytest;'
psql ${uri} -c 'CREATE TABLE sanitytest(value text);'
psql ${uri} -c "INSERT INTO sanitytest VALUES ('storage-test');"
psql ${uri} -c 'SELECT value FROM sanitytest;' | grep 'storage-test' || {
  echo Could not store and retrieve value in cluster!
  exit 1
}

echo Running pgbench
pgbench -i ${uri}
pgbench ${uri}
