#!/bin/bash

WALE_ENV_DIR=$1; shift
if [[ "${WALE_ENV_DIR}X" == "X" || ! -d ${WALE_ENV_DIR} ]]; then
  echo "USAGE: envdir.sh path/to/env/dir"
  exit 1
fi

# Ensure $WALE_S3_ENDPOINT not used in lieu of ${AWS_REGION} at the moment
# TODO: in future, revisit this relationship
if [[ "${AWS_REGION}X" != "X" ]]; then
  unset WALE_S3_ENDPOINT
fi

rm -rf $WALE_ENV_DIR/*

# only AWS currently supported
# wal_env_var_prefixes=(WAL AWS SWIFT WABS)
wal_env_var_prefixes=(WAL AWS)
for prefix in ${wal_env_var_prefixes[@]}; do
  for env in $(env | grep "^${prefix}"); do
    env_var=($(echo $env | tr "=" "\n"))
    echo ${env_var[1]} > $WALE_ENV_DIR/${env_var[0]}
  done
done

wal_env_var_count=$(ls $WALE_ENV_DIR/* | wc -l | awk '{print $1}')

# test for empty dir comes from http://stackoverflow.com/a/91639
if find $WALE_ENV_DIR/ -maxdepth 0 -empty | read v; then
  echo "No wal-e env vars"
else
  ls $WALE_ENV_DIR/*
fi
