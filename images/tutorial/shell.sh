#!/bin/bash

# USAGE:
#    ./images/tutorial/shell.sh
#    ./images/tutorial/shell.sh envdir /data/wal-e/env wal-e backup-list
# BEATLE=paul ./images/tutorial/shell.sh
set -x

BEATLE=${BEATLE:-john}
docker exec -ti ${BEATLE} ${@:-bash}
