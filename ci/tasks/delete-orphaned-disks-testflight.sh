#!/bin/bash

set +e # ok to fail; its just clean up efforts

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

disks=$(bosh disks --orphaned | grep n/a | awk '{print $2}')
for disk in $disks; do
  echo $disk | xargs -L1 bosh -n delete disk
done
