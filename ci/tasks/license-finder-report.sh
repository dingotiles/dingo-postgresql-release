#!/bin/bash

# license_finder report

set -e -x

version=$(cat version/number)
report=$PWD/license-finder-reports/dingo-postgresql-release-license-report-${version}.csv

# Populate the bosh release blobs licenses
# FIXME - this hardcoding is nasty; and yes refactoring is welcome.
cat > $report <<CSV
cf-cli, 6.16.1, "Apache 2.0", cf-cli/cf-cli_6.16.1_linux_x86-64.tgz
confd, 0.11.0, MIT, confd/confd-0.11.0-linux-amd64, https://github.com/kelseyhightower/confd/blob/master/LICENSE
aufs-tools, 20120411-3, GPL-2+, docker/aufs-tools_20120411-3_amd64.deb, http://changelogs.ubuntu.com/changelogs/pool/universe/a/aufs-tools/aufs-tools_3.2+20130722-1.1/copyright
autoconf, 2.69, GPL-2+, docker/autoconf-2.69.tar.gz
bridge-utils, 1.5, GPL-2+, docker/bridge-utils-1.5.tar.gz
docker, 1.11.0, "Apache 2.0", docker/docker-1.11.0.tgz
golang, 1.6.2, BSD, golang/go1.6.2.linux-amd64.tar.gz, https://github.com/golang/go/blob/master/LICENSE
haproxy, 1.5.12, GPL-2+, haproxy/haproxy-1.5.12.tar.gz, http://www.haproxy.org/download/1.5/doc/LICENSE
pcre, 8.37, BSD, haproxy/pcre-8.37.tar.gz
jq, 1.5, MIT, jq/jq-linux64-1.5
postgresql, 9.4.5, PostgreSQL, postgresql/postgresql-9.4.5.tar.gz, https://www.postgresql.org/about/licence/
remote_syslog, 0.14, MIT, remote_syslog/remote_syslog-0.14_linux_amd64.tar.gz, https://github.com/papertrail/remote_syslog/blob/master/LICENSE
bundler, 1.10.6, MIT, ruby/bundler-1.10.6.gem
ruby, 2.2.3, Ruby, ruby/ruby-2.2.3.tar.gz, https://www.ruby-lang.org/en/about/license.txt
rubygems, 2.5.0, Ruby, ruby/rubygems-2.5.0.tgz
libyaml, 0.1.6, MIT, ruby/yaml-0.1.6.tar.gz
CSV

# Add license for BOSH release
cat >> $report <<CSV
dingo-postgresql-release, ${version}, "Apache 2.0"
CSV

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
