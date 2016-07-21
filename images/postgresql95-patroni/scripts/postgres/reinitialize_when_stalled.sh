#!/bin/bash

# It is possible for patroni to get into an endless restart loop
# this can happen after a container was restarted after having been
# stopped in an inconsistent state.
# This has been observed often during container updates in perticular.
# This state can be identified because the /service/<id>/member/<node-id> json
# will contain {"state":"restart failed (start failed)"}
# Reinitializing patroni will fix this state

set +e

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
  fi

  sleep 2
done
