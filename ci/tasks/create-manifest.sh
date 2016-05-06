#!/bin/bash

set -e
set -x

release_name=${release_name:-"dingo-postgresql"}
manifest_dir=$PWD/manifest

dingo_postgresql_version=$(cat candidate-release/version)
etcd_version=$(cat etcd/version)
simple_remote_syslog_version=$(cat simple-remote-syslog/version)

cat > ~/.bosh_config <<EOF
---
aliases:
  target:
    bosh-lite: ${bosh_target}
auth:
  ${bosh_target}:
    username: ${bosh_username}
    password: ${bosh_password}
EOF

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
    s3_endpoint: "${s3_endpoint}"
    region: "${region}"
EOF

if [[ "${service_guid}X" != "X" ]]; then
  cat > tmp/cf-disaster-recovery.yml <<EOF
---
properties:
  cf:
    api_endpoint: api.test-cf.snw
    skip_ssl_verification: true
    user: admin
    password: admin
  servicebroker:
    service_id: "beb5973c-e1b2-11e5-a736-c7c0b526363d"
EOF
else
  cat > tmp/cf-disaster-recovery.yml <<EOF
--- {}
EOF
fi
cat tmp/cf-disaster-recovery.yml

services_template=templates/services-cluster-backup-s3.yml
# services_template=templates/services-cluster.yml

bosh target ${bosh_target}

export DEPLOYMENT_NAME=${deployment_name}
./templates/make_manifest warden ${docker_image_source} ${services_template} \
  templates/jobs-etcd.yml tmp/syslog.yml tmp/docker_image.yml tmp/backups.yml \
  tmp/releases.yml tmp/cf-disaster-recovery.yml

cp tmp/${DEPLOYMENT_NAME}*.yml ${manifest_dir}/manifest.yml

cat ${manifest_dir}/manifest.yml
