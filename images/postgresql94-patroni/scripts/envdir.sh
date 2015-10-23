#!/bin/bash

dir=$1; shift
if [[ "${dir}X" == "X" || ! -d ${dir} ]]; then
  echo "USAGE: envdir.sh path/to/env/dir"
  exit 1
fi

mkdir -p $dir
rm -rf $dir/*

wal_env_var_prefixes=(WAL AWS SWIFT WABS)
for prefix in ${wal_env_var_prefixes[@]}; do
  for env in $(env | grep "^${prefix}"); do
    env_var=($(echo $env | tr "=" "\n"))
    echo ${env_var[1]} > $dir/${env_var[0]}
  done
done

echo env director files:
ls $dir/*
