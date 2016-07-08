#!/bin/bash

set -e # fail fast

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

set +x # ok to fail/noop
set -x # print command
if ! bosh -n delete deployment ${deployment_name} -f ; then
  echo Running delete second time to try again...
  bosh -n delete deployment ${deployment_name} -f
fi
