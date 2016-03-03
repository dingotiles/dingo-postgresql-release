#!/bin/bash

dir=$1; shift
if [[ "${dir}X" == "X" || ! -d ${dir} ]]; then
  echo "USAGE: envdir.sh path/to/env/dir"
  exit 1
fi

rm -rf $dir/*

wal_env_var_prefixes=(WAL AWS SWIFT WABS)
for prefix in ${wal_env_var_prefixes[@]}; do
  for env in $(env | grep "^${prefix}"); do
    env_var=($(echo $env | tr "=" "\n"))
    echo ${env_var[1]} > $dir/${env_var[0]}
  done
done

wal_env_var_count=$(ls $dir/* | wc -l | awk '{print $1}')

# test for empty dir comes from http://stackoverflow.com/a/91639
if find $dir/ -maxdepth 0 -empty | read v; then
  echo "No wal-e env vars"
else
  ls $dir/*
fi
