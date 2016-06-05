#!/bin/bash

machine=${$1:-default}
eval $(docker-machine env ${machine})
export HOST_IP=$(docker-machine ip ${machine})
echo Running tests on host: $HOST_IP

cleanup() {
  docker-compose -p leader-election stop
  docker-compose -p leader-election rm -f
}

docker-compose -p leader-election up -d --force-recreate

run() {
  docker-compose run -e HOST_IP=${HOST_IP} -e TEST_DIR=/test-state test /scripts/$1
}
success='false'
for ((n=1;n<120;n++)); do
  echo "trying"
  if run leader_is_available.sh; then
    success='true'
    break
  fi
  sleep 1
done

if [[ $success != 'true' ]]; then
  cleanup
  exit 1
fi

run basic-storage.sh
cleanup

