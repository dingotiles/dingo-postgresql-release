#!/bin/bash

set -e #fail fast

DATA_DIR=/data
mkdir -p $DATA_DIR

DOCKER_IP=$(hostname --ip-address)

REGISTRATOR_DOCKER_IMAGE=${REGISTRATOR_DOCKER_IMAGE:-dingo-postgresql95} # used as path by registrator entries

if [[ -z "${NAME}" ]]; then
  echo "Requires \$NAME to look up container in registrator"
  exit 1
fi
if [[ -z "${PATRONI_SCOPE}" ]]; then
  echo "Requires \$PATRONI_SCOPE to advertise container and form cluster"
  exit 1
fi
if [[ -z "${ETCD_HOST_PORT}" ]]; then
  echo "Requires \$ETCD_HOST_PORT (host:port) for etcd used by registrator & patroni"
  exit 1
fi
if [[ -z "${DOCKER_HOSTNAME}" ]]; then
  echo "Requires \$DOCKER_HOSTNAME to discover public host:port from registrator"
  exit 1
fi

indent_startup() {
  c="s/^/${PATRONI_SCOPE:0:6}-startup> /"
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

(
  # look up public host:port binding from registrar entry in etcd
  # this is then advertised via patroni for replicas to connect
  i="0"
  while [[  $i -lt 4 ]]
  do
    sleep 3
    registrator_uri="${ETCD_HOST_PORT}/v2/keys/${REGISTRATOR_DOCKER_IMAGE}/${DOCKER_HOSTNAME}:${NAME}:5432"
    echo "looking up public host:port from etcd -> ${registrator_uri} ($i)"
    CONNECT_ADDRESS=$(curl -sL ${registrator_uri} | jq -r .node.value)
    if [[ "${CONNECT_ADDRESS}" == "null" ]]; then
      echo container not yet registered, waiting...
    else
      break
    fi
    i=$[$i+1]
  done
  if [[ "${CONNECT_ADDRESS}" == "null" ]]; then
    echo failed to look up container in etcd
    exit 1
  else
    echo public address ${CONNECT_ADDRESS}
  fi

  ADMIN_USERNAME=${ADMIN_USERNAME:-pgadmin}
  ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(pwgen -s -1 16)}
  SUPERUSER_USERNAME=${SUPERUSER_USERNAME:-postgres}
  SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD:-Tof2gNVZMz6Dun}
  APPUSER_USERNAME=${APPUSER_USERNAME:-dvw7DJgqzFBJC8}
  APPUSER_PASSWORD=${APPUSER_PASSWORD:-jkT3TTNebfrh6C}

  WALE_ENV_DIR=${WALE_ENV_DIR:-${DATA_DIR}/wal-e/env}
  mkdir -p $WALE_ENV_DIR

  # pass thru environment variables into an env dir for postgres user's archive/restore commands
  DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
  ${DIR}/create_envdir.sh ${WALE_ENV_DIR}

  if [[ "${NODE_GUID}X" != "X" ]]; then
    NODE_NAME=${NODE_NAME:-"pg_${PATRONI_SCOPE}_${NODE_GUID}"}
  fi
  if [[ "${BROKER_GUID}X" != "X" ]]; then
    NODE_NAME=${NODE_NAME:-"pg_${PATRONI_SCOPE}_${BROKER_GUID}"}
  fi
  NODE_NAME=${NODE_NAME:-pg_${DOCKER_IP}}

  PG_DATA_DIR=${PG_DATA_DIR:-${DATA_DIR}/postgres0}
  echo $PG_DATA_DIR > ${WALE_ENV_DIR}/PG_DATA_DIR

  if [[ "${WAL_S3_BUCKET}X" != "X" ]]; then
    if ! curl -s s3-website-us-east-1.amazonaws.com >/dev/null; then
      echo Cannot access AWS S3. Check DNS and Internet access.
      exit 1
    fi
    echo "Enabling wal-e archives to S3 bucket '${WAL_S3_BUCKET}'"
    ENVDIR="envdir ${WALE_ENV_DIR}"
    if [[ "${AWS_INSTANCE_PROFILE}X" != "X" ]]; then
      export WALE_CMD="${ENVDIR} wal-e --aws-instance-profile"
    else
      # see wal-e readme for env variables to configure for S3, Swift, etc
      export WALE_CMD="${ENVDIR} wal-e"
    fi

    export WALE_S3_PREFIX="s3://${WAL_S3_BUCKET}/backups/${PATRONI_SCOPE}/wal/"
    echo $WALE_S3_PREFIX > ${WALE_ENV_DIR}/WALE_S3_PREFIX
    echo $WALE_CMD > ${WALE_ENV_DIR}/WALE_CMD
    if [[ ! -z "${DISABLE_REGULAR_BACKUPS}" ]]; then
      echo "Disabling regular backups"
      echo $DISABLE_REGULAR_BACKUPS > ${WALE_ENV_DIR}/DISABLE_REGULAR_BACKUPS
    fi

    archive_mode="on"
    replica_methods="[wal_e,basebackup]"
    archive_command="$WALE_CMD wal-push \"%p\" -p 1"
    restore_command="$WALE_CMD wal-fetch \"%f\" \"%p\" -p 1"
  else
    echo "Disabling wal-e archives"
    archive_mode="off"
    replica_methods="[basebackup]"
    archive_command="mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f"
    restore_command="cp ../wal_archive/%f %p"
  fi


  # TODO secure the passwords!
  # TODO add host ip into postgresql.name to ensure unique if two containers have same local DOCKER_IP

  cat > /patroni/postgres.yml <<EOF
ttl: &ttl 30
loop_wait: &loop_wait 10
scope: &scope ${PATRONI_SCOPE}
restapi:
  listen: 127.0.0.1:8008
  connect_address: 127.0.0.1:8008
etcd:
  scope: *scope
  ttl: *ttl
  host: ${ETCD_HOST_PORT}
postgresql:
  name: ${NODE_NAME//./_} ## Replication slots do not allow dots in their name
  scope: *scope
  listen: 0.0.0.0:5432
  connect_address: ${CONNECT_ADDRESS}
  data_dir: ${PG_DATA_DIR}
  maximum_lag_on_failover: 1048576 # 1 megabyte in bytes
  use_slots: False
  pgpass: /tmp/pgpass
  # pg_rewind:
  #   username: postgres
  #   password: starkandwayne
  pg_hba:
  # Allow any user from any host to connect to database
  # "postgres" if the user's password is correctly supplied.
  # TYPE    DATABASE     USER            ADDRESS   METHOD
  - host    replication  dvw7DJgqzFBJC8  0.0.0.0/0 md5
  - host    postgres     all             0.0.0.0/0 md5
  - hostssl postgres     all             0.0.0.0/0 md5
  replication: # replication username, user will be created during initialization
    username: ${APPUSER_USERNAME}
    password: ${APPUSER_PASSWORD}
    network:  127.0.0.1/32
  superuser:
    username: ${SUPERUSER_USERNAME}
    password: ${SUPERUSER_PASSWORD} # password for postgres user. It would be set during initialization
  admin: # user will be created during initialization. It would have CREATEDB and CREATEROLE privileges
    username: ${ADMIN_USERNAME}
    password: ${ADMIN_PASSWORD}
  create_replica_method: ${replica_methods}
EOF

  if [[ "${WALE_CMD}X" != "X" ]]; then
    cat <<EOF >>/patroni/postgres.yml
  wal_e:
    command: /patroni/scripts/wale_restore.py
    # {key: value} below are converted to options for wale_restore.py script
    envdir: ${WALE_ENV_DIR}
    threshold_megabytes: 10240
    threshold_backup_size_percentage: 30
    retries: 2
    use_iam: 0
    no_master: 1
  restore: /patroni/scripts/restore.py
  recovery_conf:
    restore_command: ${restore_command}
EOF
fi

  cat <<EOF >>/patroni/postgres.yml
  # parameters are converted into --<name> <value> flags on the server command line
  parameters:
    # http://www.postgresql.org/docs/9.5/static/runtime-config-connection.html
    listen_addresses: 0.0.0.0
    port: 5432
    max_connections: 100
    # ssl: "on"
    # ssl_cert_file: "$SSL_CERTIFICATE"
    # ssl_key_file: "$SSL_PRIVATE_KEY"

    # http://www.postgresql.org/docs/9.5/static/runtime-config-wal.html
    wal_level: hot_standby
    wal_log_hints: "on"
    archive_mode: "${archive_mode}"
    archive_command: ${archive_command}
    archive_timeout: 10min

    # http://www.postgresql.org/docs/9.5/static/runtime-config-replication.html
    # - sending servers config
    max_wal_senders: 5
    max_replication_slots: 5
    max_wal_size: 1GB
    min_wal_size: 128MB
    wal_keep_segments: 8
    wal_sender_timeout: 60
    # - standby servers config
    hot_standby: "on"
    wal_log_hints: "on"

    # When using synchronous replication, use at least three Postgres data nodes
    # to ensure write availability if one host fails.
    # To enable a simple synchronous replication test:
    # synchronous_commit: "on"
    # synchronous_standby_names: "*"

EOF

  chown postgres:postgres -R $DATA_DIR /patroni /patroni.py ${DIR}/postgres

  if [[ -d ${PG_DATA_DIR} ]]; then
    chown postgres:postgres -R ${PG_DATA_DIR}
    chmod 700 $PG_DATA_DIR
  fi

  cat /patroni/postgres.yml

  ls ${WALE_ENV_DIR}/*

  echo ----------------------
  echo Admin user credentials
  echo Username ${ADMIN_USERNAME}
  echo Password ${ADMIN_PASSWORD}
  echo ----------------------

) 2>&1 | indent_startup

sudo -E -u postgres /scripts/postgres/start_pg.sh
