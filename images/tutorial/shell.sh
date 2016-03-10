#!/bin/bash

# USAGE:
#    ./images/tutorial/shell.sh
#    ./images/tutorial/shell.sh envdir /data/wal-e/env wal-e backup-list
# beatle=paul ./images/tutorial/shell.sh
set -x

beatle=${beatle:-john}
docker exec -ti ${beatle} ${@:-bash}
