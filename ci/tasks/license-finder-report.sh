#!/bin/bash

# license_finder report

set -e -x

version=$(cat version/number)
report=$PWD/license-finder-reports/submodules-${version}.csv

cd boshrelease


submodules=(dingo-postgresql-broker cf-containers-broker dingo-postgresql-clusterdata-backup)
for submodule in ${submodules[@]}; do
  pushd src/$submodule
    if [[ -f Gemfile ]]; then
      bundle install
    fi
    echo License Report for $submodule
    license_finder report >> $report
  popd
done

cat $report
