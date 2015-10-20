#!/bin/bash

if [[ ! -z $dockerfile_root ]]; then
  echo "USAGE dockerfile_root=boshrelease/images/postgresql94-patroni ./boshrelease/ci/tasks/prepare-dockerfile.sh"
  exit 1
fi

cp -r patroni ${dockerfile_root}/
