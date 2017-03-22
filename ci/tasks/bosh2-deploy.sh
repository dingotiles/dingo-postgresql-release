#!/bin/bash

set -e -x

cd boshrelease-ci
mkdir -p tmp

export BOSH_ENVIRONMENT=`bosh2 int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT="$(bosh2 int director-state/director-creds.yml --path /director_ssl/ca)"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh2 int director-state/director-creds.yml --path /admin_password`

cat > tmp/var.yml <<YAML
backups_clusterdata_aws_access_key_id: ${aws_access_key:?required}
backups_clusterdata_aws_secret_access_key: ${aws_secret_key:?required}
backups_database_storage_aws_access_key_id: $aws_access_key
backups_database_storage_aws_secret_access_key: $aws_secret_key

backups_database_storage_bucket_name: ${backups_bucket:?required}
backups_database_storage_region: ${region:?required}
backups_clusterdata_bucket_name: ${clusterdata_bucket:?required}
backups_clusterdata_region: ${region:?required}

cell_max_containers: 20
cf_system_domain: ${cf_system_domain:?required}
cf_admin_password: ${cf_admin_password:?required}
cf_admin_username: ${cf_admin_username:?required}
cf_skip_ssl_validation: ${cf_skip_ssl_validation:-false}
YAML

: ${docker_image_tag:?required}

bosh2 int manifests/dingo-postgresql.yml \
  --vars-store tmp/creds.yml \
  --vars-file  tmp/vars.yml \
  --var-errs > manifest/manifest.yml

bosh2 -n deploy manifest/manifest.yml

# running errands with bosh1 until bosh2 run-errand is readable
if [[ "${test_errand:-X}" != "X" ]]; then
  cat > ~/.bosh_config <<EOF
---
aliases:
  target:
    bosh-lite: "https://${BOSH_ENVIRONMENT}:25555"
auth:
  https://${BOSH_ENVIRONMENT}:25555:
    username: "${BOSH_CLIENT}"
    password: "${BOSH_CLIENT_SECRET}"
EOF
  set -x
  bosh target bosh-lite
  bosh -d manifest/manifest.yml run errand ${test_errand}
fi
