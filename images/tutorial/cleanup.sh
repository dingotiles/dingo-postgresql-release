#!/bin/bash

# USAGE: env $(cat tmp/tutorial.env | xargs) ./images/tutorial/cleanup.sh

if [[ "${ETCD_CLUSTER}X" == "X" ]]; then
  echo "Requires \$ETCD_CLUSTER"
  exit 1
fi
docker rm -f john
docker rm -f paul
curl -v "${ETCD_CLUSTER}/v2/keys/service?dir=true&recursive=true" -X DELETE
