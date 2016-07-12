#!/bin/bash

set -e #fail fast

export PG_VERSION=9.5

export PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH
DATA_DIR=/data
WALE_ENV_DIR=${WALE_ENV_DIR:-${DATA_DIR}/wal-e/env}


# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
indent_patroni() {
  c="s/^/${PATRONI_SCOPE:0:6}-patroni> /"
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

scripts_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $scripts_dir

# test for empty dir comes from http://stackoverflow.com/a/91639
if [[ ! -f ${WALE_ENV_DIR}/WALE_CMD ]]; then
  echo "WARNING: wal-e not configured, cannot start uploading base backups"
else
  echo "Starting base backups..."
  envdir ${WALE_ENV_DIR} ${scripts_dir}/regular_backup.sh
fi

if [[ -f ${WALE_ENV_DIR}/WALE_CMD ]]; then
  envdir ${WALE_ENV_DIR} ${DIR}/restore_leader_if_missing.sh
fi

echo "Starting Patroni..."
cd /
python /patroni.py /patroni/postgres.yml 2>&1 | indent_patroni
