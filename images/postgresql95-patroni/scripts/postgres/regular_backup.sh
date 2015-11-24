#!/bin/bash

if [[ -z $WALE_CMD ]]; then
  echo "Requires \$WALE_CMD; e.g. envdir \${WALE_ENV_DIR} wal-e --aws-instance-profile"
  exit 1
fi
if [[ -z ${PG_DATA_DIR} ]]; then
  echo "Requires \${PG_DATA_DIR}"
  exit 1
fi

# $BACKUP_HOUR can be an hour in the day, or * to run backup each hour
BACKUP_HOUR=${BACKUP_HOUR:-1}
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}

# run wal-e s3 backup periodically
(
  INITIAL=1
  RETRY=0
  LAST_BACKUP_TS=0
  while true
  do
    sleep 5

    CURRENT_TS=$(date +%s)
    CURRENT_HOUR=$(date +%H)
    pg_isready >/dev/null 2>&2 || continue
    IN_RECOVERY=$(psql -tqAc "select pg_is_in_recovery()")

    [[ $IN_RECOVERY != "f" ]] && echo "still in recovery" && continue
    # during initial run, count the number of backup lines. If there are
    # no backup (only line with backup-list header is returned), or there
    # is an error, try to produce a backup. Otherwise, stick to the regular
    # schedule, since we might run the backups on a freshly promoted replica.
    if [[ $INITIAL = 1 ]]
    then
      BACKUPS_LINES=$($WALE_CMD backup-list 2>/dev/null|wc -l)
      [[ $PIPESTATUS[0] = 0 ]] && [[ $BACKUPS_LINES -ge 2 ]] && INITIAL=0
    fi
    # produce backup only at a given hour, unless it's set to *, which means
    # that only backup_interval is taken into account. We also skip all checks
    # when the backup is forced because of previous attempt's failure or because
    # it's going to be a very first backup, in which case we create it unconditionally.
    if [[ $RETRY = 0 ]] && [[ $INITIAL = 0 ]]
    then
      # check that enough time has passed since the previous backup
      [[ $BACKUP_HOUR != '*' ]] && [[ $CURRENT_HOUR != $BACKUP_HOUR ]] && continue
      # get the time since the last backup. Do it only one when the hour
      # matches the backup hour.
      [[ $LAST_BACKUP_TS = 0 ]] && LAST_BACKUP_TS=$($WALE_CMD backup-list LATEST 2>/dev/null | tail -n1 | awk '{print $2}' | xargs date +%s --date)
      # LAST_BACKUP_TS will be empty on error.
      if [[ -z $LAST_BACKUP_TS ]]
      then
        LAST_BACKUP_TS=0
        echo "could not obtain latest backup timestamp"
      fi

      ELAPSED_TIME=$((CURRENT_TS-LAST_BACKUP_TS))
      [[ $ELAPSED_TIME -lt $BACKUP_INTERVAL ]] && continue
    fi
    # leave only 2 base backups before creating a new one
    $WALE_CMD delete --confirm retain 2
    # push a new base backup
    echo "producing a new backup at $(date)"
    $WALE_CMD backup-push ${PG_DATA_DIR}
    RETRY=$?
    # re-examine last backup timestamp if a new backup has been created
    if [[ $RETRY = 0 ]]
    then
      INITIAL=0
      LAST_BACKUP_TS=0
    fi
  done
) &
