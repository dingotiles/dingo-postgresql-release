#!/bin/bash

# It is possible for patroni to get into an endless restart loop
# this can happen after a container was restarted after having been
# stopped in an inconsistent state.
# This has been observed often during container updates in perticular.
# This state can be identified because the /service/<id>/member/<node-id> json
# will contain {"state":"restart failed (start failed)"}
# Reinitializing patroni will fix this state

if [[ -z "${ETCD_HOST_PORT}" ]]; then
  echo "reinitialize_when_stalled.sh: Requires \$ETCD_HOST_PORT (host:port) to lookup member state in etcd"
  exit 0
fi
if [[ -z "${PATRONI_SCOPE}" ]]; then
  echo "reinitialize_when_stalled.sh: Requires \$PATRONI_SCOPE to lookup member state in etcd"
  exit 0
fi
if [[ -z "${NODE_ID}" ]]; then
  echo "reinitialize_when_stalled.sh: Requires \$PATRONI_SCOPE to lookup member state in etcd"
  exit 0
fi

indent_reinitialize() {
  c="s/^/${PATRONI_SCOPE:0:6}-reinitialize> /"
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

while true; do
  restart_failed=$(curl -s localhost:8008/patroni \
    | jq -r '.state | startswith("restart failed")')

  if [[ ${restart_failed} == 'true' ]]; then
    echo 'Identified restart loop, reinitializing' | indent_reinitialize
    curl -s localhost:8008/reinitialize -XPOST 2>&1 | indent_reinitialize
    sleep 5
  fi

  sleep 2
done
