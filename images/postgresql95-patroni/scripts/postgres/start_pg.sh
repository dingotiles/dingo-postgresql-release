#!/bin/bash

set -e #fail fast

export PG_VERSION=9.5

export PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH
DATA_DIR=/data
WALE_ENV_DIR=${WALE_ENV_DIR:-${DATA_DIR}/wal-e/env}

# pass thru environment variables into an env dir for postgres user's archive/restore commands
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $DIR

echo "Starting backups..."
envdir ${WALE_ENV_DIR} ${DIR}/regular_backup.sh

echo "Starting Patroni..."
cd /
python /patroni.py /patroni/postgres.yml
