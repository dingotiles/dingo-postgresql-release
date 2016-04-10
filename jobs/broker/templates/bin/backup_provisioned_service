#!/bin/bash

set -e # exit immediately if a simple command exits with a non-zero status
set -u # report the usage of uninitialized variables

# NOTE: this script is called by dingo-postgresql-broker, not via monit as root user

LOG_DIR=/var/vcap/sys/log/broker
(
  export PATH=/var/vcap/packages/ruby/bin:$PATH
  export FOG_RC=/var/vcap/jobs/broker/config/backup-fog.yml

  cd /var/vcap/packages/dingo-postgresql-clusterdata-backup

  # STDIN is passed into next command
  bundle exec exe/dingo-postgresql-clusterdata-backup backup
) 2>&1 >> $LOG_DIR/broker.backup_provisioned_service.log
