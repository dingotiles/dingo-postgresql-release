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
bosh -n delete deployment ${deployment_name}

echo Running delete twice in case first delete failed...
bosh -n delete deployment ${deployment_name}
