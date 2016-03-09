#!/bin/bash

# USAGE:
#             ./images/tutorial/shell.sh
# beatle=paul ./images/tutorial/shell.sh
#             ./images/tutorial/shell.sh curl -XPOST localhost:8008/restart
# beatle=paul ./images/tutorial/shell.sh curl -XPOST localhost:8008/restart
set -x

beatle=${beatle:-john}
docker exec -ti ${beatle} ${@:-bash}
