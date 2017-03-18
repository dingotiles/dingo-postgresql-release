#!/bin/bash

set -e
set -x

release_name=${release_name:-"dingo-postgresql"}
manifest_dir=$PWD/manifest

dingo_postgresql_version=$(cat candidate-release/version)
etcd_version=$(cat etcd/version)
simple_remote_syslog_version=$(cat simple-remote-syslog/version)

export BOSH_ENVIRONMENT=`bosh2 int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT="$(bosh2 int director-state/director-creds.yml --path /director_ssl/ca)"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh2 int director-state/director-creds.yml --path /admin_password`

cat > ~/.bosh_config <<EOF
---
aliases:
  target:
    bosh-lite: ${BOSH_ENVIRONMENT}
auth:
  ${BOSH_ENVIRONMENT}:
    username: ${BOSH_CLIENT}
    password: ${BOSH_CLIENT_SECRET}
EOF
bosh target ${BOSH_ENVIRONMENT}

cd boshrelease-ci
mkdir -p tmp

cat > tmp/releases.yml <<EOF
releases:
- name: dingo-postgresql
  version: ${dingo_postgresql_version}
- name: etcd
  version: ${etcd_version}
- name: simple-remote-syslog
  version: ${simple_remote_syslog_version}
EOF

if [[ "${enable_syslog}X" == "X" ]]; then
  echo "--- {}" > tmp/syslog.yml
else
  cat > tmp/syslog.yml <<EOF
properties:
  remote_syslog:
    address: ${bosh_syslog_host}
    port: ${bosh_syslog_port}
    short_hostname: true
  docker:
    log_driver: syslog
    log_options:
    - (( concat "syslog-address=udp://" properties.remote_syslog.address ":" properties.remote_syslog.port ))
    - tag="{{.Name}}"
  haproxy:
    syslog: (( concat properties.remote_syslog.address ":" properties.remote_syslog.port ))
EOF
fi

cat > tmp/docker_image.yml <<EOF
meta:
  docker_image:
    image: ${docker_image_image}
    tag: "${docker_image_tag}"
EOF

cat > tmp/backups.yml <<EOF
---
meta:
  backups:
    aws_access_key: "${aws_access_key}"
    aws_secret_key: "${aws_secret_key}"
    backups_bucket: "${backups_bucket}"
    clusterdata_bucket: "${clusterdata_bucket}"
    region: "${region}"
EOF

cat > tmp/cf.yml <<EOF
---
meta:
  cf:
    api_url: https://api.system.test-cf.snw
    skip_ssl_validation: true
    skip_ssl_verification: true
    username: admin
    password: A8tb4yRlQ3BmKmc1TQSCgiN7rAQXiQ73PkeoyI1qGTHq8y523kPZWjGyedjal6kx
properties:
  servicebroker:
    service_id: beb5973c-e1b2-11e5-a736-c7c0b526363d
EOF
cat tmp/cf.yml

services_template=templates/services-cluster-backup-s3.yml
# services_template=templates/services-cluster.yml

export DEPLOYMENT_NAME=${deployment_name}
./templates/make_manifest warden ${docker_image_source} ${services_template} \
  templates/jobs-etcd.yml templates/integration-test.yml templates/cf.yml \
  tmp/syslog.yml tmp/docker_image.yml tmp/backups.yml \
  tmp/releases.yml tmp/cf.yml

cp tmp/${DEPLOYMENT_NAME}*.yml ${manifest_dir}/manifest.yml

cat ${manifest_dir}/manifest.yml
