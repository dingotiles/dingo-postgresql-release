#!/bin/bash

# USAGE echo '{"credentials": {"uri": "postgresql://drnic@localhost:5432/booktown-restore"}}' |
#   ./restore.sh /path/to/backup.tgz /tmp/restore
exec 1>&2 # redirect all output to stderr for logging

backup_path=$1; shift
tmp_dir=${1:-/tmp}; shift

if [[ "${backup_path}X" == "X" ]]; then
  echo "USAGE ./bin/restore.sh <backup_path> [<tmp_dir>]"
  exit 1
fi

set -e
set -x

payload=$(mktemp /tmp/backup-in.XXXXXX)
cat > $payload <&0

uri=$(jq -r '.credentials.uri // ""' < $payload)

if [[ "${uri}X" == "X" ]]; then
  echo "STDIN requires .credentials.uri for postgresql DB"
  exit 1
fi

echo "importing to psql $PG_VERSION"
pg_restore -d $uri --no-owner --no-privileges --clean ${backup_path}
