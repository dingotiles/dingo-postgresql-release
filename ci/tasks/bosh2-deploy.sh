#!/bin/bash

set -e -x

cd boshrelease-ci

cat > tmp/s3-creds.yml <<YAML
aws_access_key: ${aws_access_key:?required}
aws_secret_key: ${aws_secret_key:?required}
backups_bucket: ${backups_bucket:?required}
clusterdata_bucket: ${clusterdata_bucket:?required}
region: ${region:?required}
YAML
