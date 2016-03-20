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
    s3_bucket: "${s3_bucket}"
    s3_endpoint: "${s3_endpoint}"
EOF

cat > tmp/release_version.yml <<EOF
---
meta:
  release_version: ${VERSION}
EOF

spruce merge --prune meta \
  ci/manifests/vsphere.s3-backups.yml \
  tmp/backups.yml tmp/release_version.yml \
    > ${output_manifest}
