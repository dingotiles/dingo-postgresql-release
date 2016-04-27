#!/bin/bash

set -x
set -e

broker_ip=10.58.111.45
cat $PWD/service-info/service-guid

cf login --skip-ssl-validation \
  -a api.test-cf.snw \
  -u admin \
  -p admin \
  -o dr-test \
  -s dr-test

cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;' | grep 'dr-test'

cf delete-service-key -f dr-test dr-test-binding
cf delete-service -f dr-test
cf delete-service-broker -f testflight-dingo-pg
