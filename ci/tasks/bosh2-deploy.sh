#!/bin/bash

set -e

manifest_dir=$(pwd)/manifest

export BOSH_ENVIRONMENT=`bosh2 int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT="$(bosh2 int director-state/director-creds.yml --path /director_ssl/ca)"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh2 int director-state/director-creds.yml --path /admin_password`

cd boshrelease-ci
mkdir -p tmp

cat > tmp/vars.yml <<YAML
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

cat > tmp/docker_image_tag.yml <<YAML
---
- type: replace
  path: /instance_groups/name=cell/properties/broker/services/name=dingo-postgresql/plans/name=cluster/container/tag
  value: ${docker_image_tag:?required}
YAML

cat > tmp/deployment.yml <<YAML
---
- type: replace
  path: /name
  value: ${deployment_name:?required}

- type: replace
  path: /instance_groups/name=router/networks/name=public/static_ips/0
  value: ${deployment_router_ip:?required}
YAML

set -x
bosh2 int manifests/dingo-postgresql.yml \
  -o           tmp/docker_image_tag.yml  \
  -o           tmp/deployment.yml   \
  --vars-store tmp/creds.yml \
  --vars-file  tmp/vars.yml  \
  --var-errs \
    > $manifest_dir/manifest.yml

export BOSH_DEPLOYMENT=$deployment_name
bosh2 -n deploy $manifest_dir/manifest.yml

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
  bosh -d $manifest_dir/manifest.yml run errand ${test_errand}
fi
