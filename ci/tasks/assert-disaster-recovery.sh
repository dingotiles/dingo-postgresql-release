#!/bin/bash

set -x
set -e

cf login --skip-ssl-validation \
  -a api.test-cf.snw \
  -u admin \
  -p admin \
  -o dr-test \
  -s dr-test

cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

set +x
for ((n=0;n<60;n++)); do
    found='false'
    set -x
    table=$(psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;')
    set +x
    if echo ${table} | grep 'dr-test'; then
        found='true'
        break
    fi
    sleep 1
done
set -x

if [[ ${found} != 'true' ]]; then
    exit 1
fi

cf delete-service-key -f dr-test dr-test-binding
cf delete-service -f dr-test
cf delete-service-broker -f testflight-dingo-pg
