#!/bin/bash

set -e # fail fast
set -x # print commands

if [[ "${aws_access_key_id}X" == "X" ]]; then
  echo 'Require $aws_access_key_id, $aws_secret_access_key'
  exit 1
fi

cat > boshrelease/config/private.yml << EOF
---
blobstore:
  s3:
    access_key_id: ${aws_access_key_id}
    secret_access_key: ${aws_secret_access_key}
EOF

cd boshrelease
gem install rake --no-ri --no-rdoc

bosh -n sync blobs

rake images:cleanout
rake images:package
rake jobs:update_spec

bosh -n upload blobs

if [[ -z "$(git config --global user.name)" ]]
then
  git config --global user.name "Concourse Bot"
  git config --global user.email "drnic+bot@starkandwayne.com"
fi

git commit -a -m "updated image layers"
