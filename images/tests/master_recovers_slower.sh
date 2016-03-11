#!/bin/bash

set -e -x

docker-compose down || true
tutorial/cleanup-s3.sh

docker-compose up -d john
sleep 10
tutorial/pgbench.sh

docker-compose stop john; docker-compose rm -f
sleep 30
docker-compose up john
