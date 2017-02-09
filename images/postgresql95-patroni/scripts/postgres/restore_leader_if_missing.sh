#!/bin/bash

# restore_leader_if_missing.sh is a workaround for patroni not currently
# having a way to replicate a new leader from a wal-e backup.
#
# The idea is that patroni can create a replica from wal-e if there is a leader
# though I'm not sure why a leader is required. That's future work in patroni.
#
# So this script will create a fake leader to trick patroni into restoring a new
# leader from wal-e backup.
#
# It will only run the restoration process if:
# * there is no current leader,
# * if there is no local DB initialized, and
# * if there is a wal-e backup available

set -e # fail fast

if [[ -z $WALE_CMD ]]; then
  echo "restore_leader_if_missing.sh: Requires \$WALE_CMD; e.g. envdir \${WALE_ENV_DIR} wal-e --aws-instance-profile"
  exit 0
fi
if [[ -z ${PG_DATA_DIR} ]]; then
  echo "restore_leader_if_missing.sh: Requires \${PG_DATA_DIR}"
  exit 0
fi
if [[ -z "${PATRONI_SCOPE}" ]]; then
  echo "restore_leader_if_missing.sh: Requires \$PATRONI_SCOPE to report backup-list for service"
  exit 0
fi
if [[ -z "${ETCD_HOST_PORT}" ]]; then
  echo "restore_leader_if_missing.sh: Requires \$ETCD_HOST_PORT (host:port) to update backup-list data to etcd"
  exit 0
fi
if [[ -z "${WALE_S3_PREFIX}" ]]; then
  echo "restore_leader_if_missing.sh: Requires \$WALE_S3_PREFIX into which to store sysid"
  exit 0
fi
if [[ -z "${WAL_S3_BUCKET}" ]]; then
  echo "restore_leader_if_missing.sh: Requires \$WAL_S3_BUCKET into which to store sysid"
  exit 0
fi

indent_restore_leader() {
  c="s/^/${PATRONI_SCOPE:0:6}-restore_leader_if_missing> /"
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

(
  if [[ "$(curl -s ${ETCD_HOST_PORT}/v2/keys/service/${PATRONI_SCOPE}/leader | jq -r .node.value)" != "null" ]]; then
    echo "leader exists, no additional preparation required for container to join cluster"
    exit 0
  fi
  if [[ -d ${PG_DATA_DIR}/global ]]; then
    echo "local database exists; no additional preparation required to restart container"
    exit 0
  fi

  echo wal-e backup-list
  $WALE_CMD backup-list

  BACKUPS_LINES=$($WALE_CMD backup-list 2>/dev/null|wc -l)
  if [[ $BACKUPS_LINES -lt 2 ]]; then
    echo "new cluster, no existing backup to restore"
    exit 0
  fi

  # must have /initialize set
  if [[ "$(curl -s ${ETCD_HOST_PORT}/v2/keys/service/${PATRONI_SCOPE}/initialize | jq -r .node.value)" == "null" ]]; then
    echo "etcd missing /initialize system ID, fetching from ${WALE_S3_PREFIX}sysids"
    region=$(aws s3api get-bucket-location --bucket ${WAL_S3_BUCKET} | jq -r '.LocationConstraint')
    if [[ ${region} != 'null' ]]; then
      region_option="--region ${region}"
    fi
    aws s3 ${region_option} sync ${WALE_S3_PREFIX}sysids /tmp/sysids

    if [[ ! -f /tmp/sysids/sysid ]]; then
      echo "Target ${WALE_S3_PREFIX} missing /sysids/sysid for original 'Database system identifier'"
      exit 1
    fi

    echo "Re-initializing /${PATRONI_SCOPE}/initialize with original 'Database system identifier'"
    curl -s ${ETCD_HOST_PORT}/v2/keys/service/${PATRONI_SCOPE}/initialize -XPUT -d "value=$(cat /tmp/sysids/sysid)"
  fi

  echo "preparing patroni to restore this container from wal-e backups"
) 2>&1 | indent_restore_leader
