#!/bin/bash

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

bosh target ${bosh_target}
bosh deployment ${manifest}

mkdir logs
cd logs
bosh logs router 0

# bosh1 creates file: job.index.timestamp.tgz
# bosh2 creates file: deployment.job.UUID-timestamp.tgz
tar xfz *router*.tgz

rm -f *router*.tgz
ls -al */*

set -x

cat broker/broker.backup_provisioned_service.log

# currently broker sends stderr to stdout as well; so only need to show stdout.log
cat broker/broker.stdout.log
