#!/bin/bash

WALE_ENV_DIR=$1; shift
if [[ "${WALE_ENV_DIR}X" == "X" || ! -d ${WALE_ENV_DIR} ]]; then
  echo "USAGE: envdir.sh path/to/env/dir"
  exit 1
fi

rm -rf $WALE_ENV_DIR/*

wal_env_var_prefixes=(WAL AWS SWIFT WABS)
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
  # setup additional env vars for reporting backups via ETCD
  echo ${PATRONI_SCOPE} > $WALE_ENV_DIR/PATRONI_SCOPE
  echo ${ETCD_HOST_PORT} > $WALE_ENV_DIR/ETCD_HOST_PORT

  ls $WALE_ENV_DIR/*
fi
