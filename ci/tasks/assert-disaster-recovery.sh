#!/bin/bash

set -x
set -e

cf api api.test-cf.snw --skip-ssl-validation
cf auth admin admin
cf t -o dr-test -s dr-test

cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

set +x
for ((n=0;n<180;n++)); do
    found='false'
    set -x
    table=$(psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;' || true)
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
