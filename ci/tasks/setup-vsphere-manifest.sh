#!/bin/bash

output_manifest=$(pwd)/vsphere-manifest/manifest.yml
VERSION="$(cat version/number)"

cd boshrelease-ci
mkdir -p tmp

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

cat > tmp/syslog.yml <<EOF
properties:
  remote_syslog:
    address: ${syslog_host}
    port: "${syslog_port}"
    short_hostname: true
  docker:
    log_driver: syslog
    log_options:
    - syslog-address=udp://${syslog_host}:${syslog_port}
    - tag="{{.Name}}"
  haproxy:
    syslog: ${syslog_host}:${syslog_port}
EOF

cat > tmp/release_version.yml <<EOF
---
meta:
  release_version: ${VERSION}
EOF

spruce merge --prune meta \
  ci/manifests/vsphere.s3-backups.yml \
  tmp/backups.yml \
  tmp/syslog.yml \
  tmp/release_version.yml \
    > ${output_manifest}

cat ${output_manifest}
