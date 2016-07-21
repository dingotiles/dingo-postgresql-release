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

bosh disks --orphaned | grep n/a | awk '{print $2}' | xargs -L1 bosh -n delete disk
