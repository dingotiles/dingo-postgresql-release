#!/bin/bash

set -e #fail fast

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

indent_shutdown() {
  c="s/^/${PATRONI_SCOPE:0:6}-shutdown> /"
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

shutdown() {
  (
    echo "SIGTERM received"
    echo "Attempting to failover from ${NODE_ID}"
    curl -s localhost:8008/failover -XPOST -d "{ \"leader\":\"${NODE_ID}\" }"
    echo

    echo "Shutting down patroni"
  ) 2>&1 | indent_shutdown

  local patroni_pid=$(ps aux | grep '^postgres.*python /patroni.py' | awk '{ print $2 }' | head -n 1)
  kill -s SIGTERM  "${patroni_pid}"
  wait ${patroni_pid}
}

trap shutdown TERM

scripts_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $scripts_dir

if [[ -f ${WALE_ENV_DIR}/WALE_CMD ]]; then
  export WALE_CMD=$(cat ${WALE_ENV_DIR}/WALE_CMD)
  export WALE_S3_PREFIX=$(cat ${WALE_ENV_DIR}/WALE_S3_PREFIX)
  ${scripts_dir}/restore_leader_if_missing.sh
fi

echo "Starting Patroni..."
cd /
python /patroni.py /patroni/postgres.yml 2>&1 | indent_patroni &
patroni_pid=$!

if [[ ! -f ${WALE_ENV_DIR}/WALE_CMD ]]; then
  echo "WARNING: wal-e not configured, cannot start uploading base backups"
else
  echo "Starting base backups..."
  export WALE_CMD=$(cat ${WALE_ENV_DIR}/WALE_CMD)
  export WALE_S3_PREFIX=$(cat ${WALE_ENV_DIR}/WALE_S3_PREFIX)
  ${scripts_dir}/regular_backup.sh
fi

${scripts_dir}/reinitialize_when_stalled.sh &
${scripts_dir}/self_advertize.sh &

wait ${patroni_pid}
