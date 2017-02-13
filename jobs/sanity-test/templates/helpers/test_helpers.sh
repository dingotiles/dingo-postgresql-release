wait_for_database() {
  set +e
  uri=$1
  if [[ "${uri}X" == "X" ]]; then
    echo "USAGE: wait_for_database uri"
    exit 1
  fi

  for ((n=0;n<30;n++)); do
    in_recovery=$(psql ${uri} -c "SELECT row_to_json(t1) FROM (SELECT pg_is_in_recovery()) t1;" -t | jq -r .pg_is_in_recovery)
    if [[ "${in_recovery}" == "false" ]]; then
      echo "Database finished recovering"
      set -e
      break
    fi
    echo "Database still recovering"
    sleep 10
  done
  if [[ "${in_recovery}" != "false" ]]; then
    echo "Data was still in recovery after 300s"
    exit 1
  fi

  # TODO: currently testing 1-node clusters; so do not wait for replicas
  # for ((n=0;n<30;n++)); do
  #   replicas=$(psql ${uri} -c "select count(*) from pg_stat_replication;" -t | jq -r .)
  #   if [[ "$replicas" != "0" ]]; then
  #     echo "Now targetting leader with $replicas replicas"
  #     break
  #   fi
  #   echo "Currently targeting read-only replica or leader has no replicas yet"
  #   sleep 5
  # done
  # if [[ "$replicas" == "0" ]]; then
  #   echo "After 150s still targeting read-only replica or leader has no replicas yet"
  #   exit 1
  # fi
}

display_wale_backup_status() {
  instance_id=$1
  if [[ "${instance_id}X" == "X" ]]; then
    echo "USAGE: display_wale_backup_status instance_id"
    exit 1
  fi

  echo Display wal-e backup status
  curl -s ${ETCD}/v2/keys/service/${instance_id}/wale-backup-list | jq -r .node.value
}
