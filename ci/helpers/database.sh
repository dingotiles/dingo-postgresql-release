wait_for_database_recovery() {
  uri=$1
  if [[ "${uri}X" == "X" ]]; then
    echo "USAGE: wait_for_database_recovery uri"
    exit 1
  fi

  for ((n=0;n<30;n++)); do
    in_recovery=$(psql ${uri} -c "SELECT row_to_json(t1) FROM (SELECT pg_is_in_recovery()) t1;" -t | jq -r .pg_is_in_recovery)
    if [[ "${in_recovery}" == "false" ]]; then
      echo "Database finished recovering"
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
