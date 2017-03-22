#!/bin/bash

set -x

source boshrelease-ci/ci/helpers/database.sh

# To avoid 'WARNING: terminal is not fully functional'
export PAGER=/bin/cat

: ${cf_system_domain:?required}
: ${cf_admin_username:?required}
: ${cf_admin_password:?required}
: ${cf_skip_ssl_validation:?required}

cf api api.$cf_system_domain --skip-ssl-validation
cf auth $cf_admin_username $cf_admin_password

cf create-org dr-test; cf target -o dr-test
cf create-space dr-test
set -e
cf target -s dr-test

cf service-key dr-test dr-test-binding
pg_uri=$(cf service-key dr-test dr-test-binding | grep '"uri"' | grep -o 'postgres://.*/postgres' | sed "s/@.*:/@${router_ip}:/")

set +x
wait_for_database $pg_uri

for ((n=0;n<30;n++)); do
    found='false'
    set -x
    table=$(psql ${pg_uri} -c 'SELECT * FROM disasterrecoverytest;' || true)
    set +x
    if echo ${table} | grep 'dr-test'; then
        found='true'
        break
    fi
    sleep 10
done
set -x

if [[ ${found} != 'true' ]]; then
    exit 1
fi

cf delete-service-key -f dr-test dr-test-binding
cf delete-service -f dr-test
cf delete-service-broker -f testflight-dingo-pg
