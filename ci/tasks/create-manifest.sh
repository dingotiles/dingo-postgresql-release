#!/bin/bash

set -e
set -x

release_name=${release_name:-"dingo-postgresql"}
manifest_dir=$PWD/manifest

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
    s3_bucket: "${s3_bucket}"
    s3_endpoint: "${s3_endpoint}"
EOF
services_template=templates/services-solo-backup-s3.yml
# services_template=templates/services-solo.yml

bosh target ${bosh_target}

export DEPLOYMENT_NAME=${deployment_name}
./templates/make_manifest warden ${docker_image_source} ${services_template} \
  templates/jobs-etcd.yml tmp/syslog.yml tmp/docker_image.yml tmp/backups.yml

cp tmp/${DEPLOYMENT_NAME}*.yml ${manifest_dir}/manifest.yml

cat ${manifest_dir}/manifest.yml
