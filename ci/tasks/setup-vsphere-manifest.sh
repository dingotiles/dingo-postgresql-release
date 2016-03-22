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
    s3_endpoint: "${s3_endpoint}"
    region: "${region}"
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

cat ${output_manifest}
