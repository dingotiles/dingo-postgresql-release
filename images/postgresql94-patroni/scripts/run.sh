#!/bin/bash

DATA_DIR=/data
mkdir -p $DATA_DIR

DOCKER_IP=$(hostname --ip-address)

REGISTRATOR_PREFIX=${REGISTRATOR_PREFIX:-}
REGISTRATOR_DOCKER_IMAGE=${REGISTRATOR_DOCKER_IMAGE:-postgresql-patroni} # used as path by registrator entries

PATRONI_SCOPE=${PATRONI_SCOPE:-$NAME}

if [[ -z "${PATRONI_SCOPE}" ]]; then
  echo "Requires \$PATRONI_SCOPE or \$NAME to advertise container and form cluster"
  exit 1
fi
if [[ -z "${ETCD_HOST_PORT}" ]]; then
  echo "Requires \$ETCD_HOST_PORT (host:port) for etcd used by registrator & patroni"
  exit 1
fi

# look up public host:port binding from registrar entry in etcd
# this is then advertised via patroni for replicas to connect
if [[ ! -z "${DOCKER_HOSTNAME}" ]]; then
  i="0"
  while [[  $i -lt 4 ]]
  do
    sleep 3
    registrator_uri="${ETCD_HOST_PORT}/v2/keys/${REGISTRATOR_DOCKER_IMAGE}/${DOCKER_HOSTNAME}:${NAME}:5432"
    echo looking up public host:port from etc
    echo "-> ${registrator_uri}"
    CONNECT_ADDRESS=$(curl -vL ${registrator_uri} | jq -r .node.value)
    if [[ "${CONNECT_ADDRESS}" == "null" ]]; then
      echo container not yet registered, waiting...
    else
      break
    fi
    i=$[$i+1]
  done
  if [[ "${CONNECT_ADDRESS}" == "null" ]]; then
    echo failed to look up container in etcd; failing over to local docker IP only
  fi
fi
# else fail back to local docker ip advertisement (single docker engine only)
CONNECT_ADDRESS=${CONNECT_ADDRESS:-${DOCKER_IP}:5432}

POSTGRES_USERNAME=${POSTGRES_USERNAME:-pgadmin}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(pwgen -s -1 16)}

PG_DATA_DIR=${PG_DATA_DIR:-${DATA_DIR}/postgres0}

WALE_ENV_DIR=${WALE_ENV_DIR:-${DATA_DIR}/wal-e/env}
mkdir -p $WALE_ENV_DIR

if [[ "${NODE_GUID}X" != "X" ]]; then
  NODE_NAME=${NODE_NAME:-"pg_${PATRONI_SCOPE}_${NODE_GUID}"}
fi
if [[ "${BROKER_GUID}X" != "X" ]]; then
  NODE_NAME=${NODE_NAME:-"pg_${PATRONI_SCOPE}_${BROKER_GUID}"}
fi
NODE_NAME=${NODE_NAME:-pg_${DOCKER_IP}}

# pass thru environment variables into an env dir for postgres user's archive/restore commands
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
${DIR}/envdir.sh ${WALE_ENV_DIR}

if [[ "${WAL_S3_BUCKET}X" != "X" ]]; then
  if [[ "${AWS_INSTANCE_PROFILE}X" != "X" ]]; then
    archive_command="wal-e --aws-instance-profile wal-push '%p' -p 1"
    restore_command="wal-e --aws-instance-profile wal-fetch '%f' '%p' -p 1"
  else
    # see wal-e readme for env variables to configure for S3, Swift, etc
    archive_command="wal-e wal-push '%p' -p 1"
    restore_command="wal-e wal-fetch '%f' '%p' -p 1"
  fi
  # postgres user needs to load its env variables for each wal-e command
  archive_command="envdir ${WALE_ENV_DIR} ${archive_command}"
  restore_command="envdir ${WALE_ENV_DIR} ${restore_command}"
else
  archive_command="mkdir -p ../wal_archive && cp %p ../wal_archive/%f"
fi


# TODO secure the passwords!
# TODO fix hard-coded bosh-lite 10.244.0.0/16
# TODO add host ip into postgresql.name to ensure unique if two containers have same local DOCKER_IP

cat > /patroni/postgres.yml <<__EOF__
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
  pg_hba:
  - host all all 0.0.0.0/0 md5
  - hostssl all all 0.0.0.0/0 md5
  - host replication replicator 0.0.0.0/0 md5
  replication: # replication username, user will be created during initialization
    username: replicator
    password: replicator
    network:  127.0.0.1/32
  superuser:
    password: starkandwayne # password for postgres user. It would be set during initialization
  admin: # user will be created during initialization. It would have CREATEDB and CREATEROLE privileges
    username: ${POSTGRES_USERNAME}
    password: ${POSTGRES_PASSWORD}
  # restore: /patroni/scripts/restore.py
  # recovery_conf:
  #  restore_command: "${restore_command}"

  # parameters are converted into --<name> <value> flags on the server command line
  parameters:
    # http://www.postgresql.org/docs/9.4/static/runtime-config-connection.html
    listen_addresses: 0.0.0.0
    port: 5432
    max_connections: 100
    # ssl: "on"
    # ssl_cert_file: "$SSL_CERTIFICATE"
    # ssl_key_file: "$SSL_PRIVATE_KEY"

    # http://www.postgresql.org/docs/9.4/static/runtime-config-wal.html
    wal_level: hot_standby
    wal_log_hints: "on"
    #archive_mode: "on"
    #archive_command: "${archive_command}"
    #archive_timeout: 60s

    # http://www.postgresql.org/docs/9.4/static/runtime-config-replication.html
    # - sending servers config
    max_wal_senders: 5
    max_replication_slots: 5
    wal_keep_segments: 8
    wal_sender_timeout: 60
    # - standby servers config
    hot_standby: "on"
    wal_log_hints: "on"
__EOF__

chown postgres:postgres -R $DATA_DIR $PG_DATA_DIR /patroni /pgpass /patroni.py
chmod 700 $PG_DATA_DIR
cat /patroni/postgres.yml

echo ----------------------
echo Admin user credentials
echo Username ${POSTGRES_USERNAME}
echo Password ${POSTGRES_PASSWORD}
echo ----------------------

sudo -u postgres /scripts/start_pg.sh
