#!/bin/bash

# USAGE: env $(cat tmp/tutorial-wale.env | xargs) ./images/tutorial/s3-contents.sh


if [[ "${WAL_S3_BUCKET}X" == "X" ]]; then
  echo "Requires \$WAL_S3_BUCKET"
  exit 1
fi

PATRONI_SCOPE=${PATRONI_SCOPE:-my_first_cluster}

if [[ "${WAL_S3_BUCKET}X" != "X" ]]; then
  set -x # print commands
  aws s3 ls --recursive s3://${WAL_S3_BUCKET}/backups/${PATRONI_SCOPE}
fi
