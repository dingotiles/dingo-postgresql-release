#!/bin/bash

outdir=$PWD/broker-info
broker_ip=10.58.111.45
set -x

cf login --skip-ssl-validation \
  -a api.test-cf.snw \
  -u admin \
  -p admin \

cf create-org dr-test; cf target -o dr-test
cf create-space dr-test; cf target -s dr-test

cf delete-service-key -f dr-test dr-test-binding
cf delete-service -f dr-test
cf delete-service-broker -f testflight-dingo-pg
cf create-service-broker testflight-dingo-pg starkandwayne starkandwayne http://${broker_ip}:8888


cf curl /v2/service_brokers | \
  jq -r '.resources[].metadata.guid' | \
  tee ${outdir}/broker-guid

cf enable-service-access dingo-postgresql
cf marketplace

cf create-service dingo-postgresql cluster dr-test

cf create-service-key dr-test dr-test-binding
cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")
superuser_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

psql ${pg_uri} -c 'CREATE TABLE disasterrecoverytest (value text);'
psql ${pg_uri} -c "INSERT INTO disasterrecoverytest VALUES ('dr-test');"
psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;'
