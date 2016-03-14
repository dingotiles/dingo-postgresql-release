#!/bin/bash

if [[ -z ${PG_DATA_DIR} ]]; then
  echo "backup_sysid.sh: Requires \${PG_DATA_DIR}"
  exit 0
fi
if [[ -z "${WALE_S3_PREFIX}" ]]; then
  echo "backup_sysid.sh: Requires \$WALE_S3_PREFIX into which to store sysid"
  exit 0
fi

pg_controldata ${PG_DATA_DIR}

mkdir -p /tmp/sysids
pg_controldata ${PG_DATA_DIR} | grep "Database system identifier" | cut -d ":" -f2 | awk '{print $1}' > /tmp/sysids/sysid

aws s3 sync /tmp/sysids ${WALE_S3_PREFIX}sysids
