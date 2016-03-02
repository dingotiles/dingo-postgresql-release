#!/bin/bash

set -e

version=$(cat version/number)
release_name=${release_name:-"patroni-docker"}

git clone boshrelease final-release
cd final-release

cat > config/private.yml << EOF
---
blobstore:
  s3:
    access_key_id: ${aws_access_key_id}
    secret_access_key: ${aws_secret_access_key}
EOF

bosh -n create release --final -v ${version}

if [[ -z "$(git config --global user.name)" ]]
then
  git config --global user.name "Concourse Bot"
  git config --global user.email "drnic+bot@starkandwayne.com"
fi

git add -A
git commit -m "release v${version}"
