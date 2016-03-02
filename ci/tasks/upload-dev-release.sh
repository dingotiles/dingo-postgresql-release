#!/bin/bash

set -e
set -x

release_name=${release_name:-"patroni-docker"}

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

cd boshrelease
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

bosh target ${bosh_target}

bosh create release --name ${release_name}
bosh -n upload release --rebase

bosh -n upload release https://bosh.io/d/github.com/cloudfoundry-community/simple-remote-syslog-boshrelease
bosh -n upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release

./templates/make_manifest warden upstream templates/jobs-etcd.yml tmp/syslog.yml
bosh -n deploy
