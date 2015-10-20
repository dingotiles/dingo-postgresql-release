#!/bin/bash

# USAGE echo '{"credentials": {"uri": "postgresql://drnic@localhost:5432/booktown"}}' |
#   ./backup.sh /path/to/backup.tgz xyz /tmp/backups/xyz.tgz

exec 1>&2 # redirect all output to stderr for logging

service_id=$1; shift
store_path=$1; shift

if [[ "${store_path}X" == "X" ]]; then
  echo "USAGE ./bin/backup.sh <service_id> <store_path>"
  exit 1
fi

payload=$(mktemp /tmp/backup-in.XXXXXX)
cat > $payload <&0

uri=$(jq -r '.credentials.uri // ""' < $payload)

if [[ "${uri}X" == "X" ]]; then
  echo "STDIN requires .credentials.uri for postgresql DB"
  exit 1
fi

mkdir -p $(dirname $store_path)

echo "dumping from psql $PG_VERSION"
pg_dump --no-owner --no-privileges --verbose -f $store_path -Fc $uri
