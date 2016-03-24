#!/bin/bash

set -e # fail fast
set -x # print commands

releases=(etcd simple-remote-syslog)
for release in "${releases[@]}"; do
  version=$(cat $release/version)
  mv $release/release.tgz dependency-releases/$release-$version.tgz
done
