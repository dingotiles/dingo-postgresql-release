wait_for_database_recovery() {
  set +e
  uri=$1
  if [[ "${uri}X" == "X" ]]; then
    echo "USAGE: wait_for_database_recovery uri"
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
