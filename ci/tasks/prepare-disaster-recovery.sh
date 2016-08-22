#!/bin/bash

set -x
set -e

echo Waiting a few seconds for the docker images to pull
sleep 30

cf api api.test-cf.snw --skip-ssl-validation
cf auth admin admin
cf t -o dr-test -s dr-test

cf create-org dr-test; cf target -o dr-test
cf create-space dr-test; cf target -s dr-test

cf marketplace
cf service-brokers
cf service-access

cf purge-service-offering -f dingo-postgresql
cf delete-service-broker -f testflight-dingo-pg

cf create-service-broker testflight-dingo-pg starkandwayne starkandwayne http://${broker_ip}:${broker_port}

cf enable-service-access dingo-postgresql
cf marketplace -s dingo-postgresql

cf create-service dingo-postgresql cluster dr-test
echo 'Waiting for async provisioning to complete'
set +x
sleep 5
for ((n=0;n<120;n++)); do
    if cf service dr-test | grep 'create succeeded'; then
        break
    fi
    sleep 1
done
set -x

instance_id=$(cf curl /v2/service_instances | jq -r '.resources[0].metadata.guid')

cf create-service-key dr-test dr-test-binding
cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")
superuser_uri=$(cf service-key dr-test dr-test-binding | grep '"superuser_uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${broker_ip}:/")

psql ${pg_uri} -c 'CREATE TABLE disasterrecoverytest (value text);'
psql ${pg_uri} -c "INSERT INTO disasterrecoverytest VALUES ('dr-test');"
psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;'

echo Deleting instance
curl -sf ${BROKER_URI}/v2/service_instances/${instance_id}\?plan_id=${plan_id}\&service_id=${service_id} \
     -XDELETE
