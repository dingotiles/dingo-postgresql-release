#!/bin/bash

outdir=$PWD/service-info
set -x

cf login --skip-ssl-validation \
  -a api.test-cf.snw \
  -u admin \
  -p admin \

cf create-org dr-test; cf target -o dr-test
cf create-space dr-test; cf target -s dr-test

cf purge-service-instance -f dr-test
cf purge-service-offering -f testflight-dingo-pg
cf delete-service-broker -f testflight-dingo-pg

cf create-service-broker testflight-dingo-pg starkandwayne starkandwayne http://${broker_ip}:${broker_port}


cf curl /v2/services | \
  jq -r '.resources[0].metadata.guid' | \
  tee ${outdir}/service-guid

cf enable-service-access dingo-postgresql
cf marketplace

cf create-service dingo-postgresql cluster dr-test

instance_id=$(cf curl /v2/service_instances | jq -r '.resources[0].metadata.guid')

cf create-service-key dr-test dr-test-binding
cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")
superuser_uri=$(cf service-key dr-test dr-test-binding | grep '"superuser_uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

psql ${pg_uri} -c 'CREATE TABLE disasterrecoverytest (value text);'
psql ${pg_uri} -c "INSERT INTO disasterrecoverytest VALUES ('dr-test');"
psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;'

psql ${superuser_uri} -c "select pg_switch_xlog();"

echo wait 10 seconds for WAL archive flush to complete
sleep 10

echo Deleting instance
curl -sf ${BROKER_URI}/v2/service_instances/${instance_id}\?plan_id=${plan_id}\&service_id=${service_id} \
     -XDELETE
