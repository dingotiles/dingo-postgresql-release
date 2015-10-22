#!/bin/bash

touch /pgpass

DATA_DIR=/data
mkdir -p $DATA_DIR

DOCKER_IP=$(hostname --ip-address)

# determine host:port to advertise into etcd for replication
if [[ "${HOSTPORT_5432_TCP}X" != "X" ]]; then
  CONNECT_ADDRESS=${HOSTPORT_5432_TCP}
fi
CONNECT_ADDRESS=${CONNECT_ADDRESS:-${DOCKER_IP}:5432}


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
  host: ${ETCD_CLUSTER}
postgresql:
  name: postgresql_${DOCKER_IP//./_} ## Replication slots do not allow dots in their name
  scope: *scope
  listen: 0.0.0.0:5432
  connect_address: ${CONNECT_ADDRESS}
  data_dir: /data/postgres0
  maximum_lag_on_failover: 1048576 # 1 megabyte in bytes
  use_slots: False
  pgpass: /tmp/pgpass
  pg_hba:
  - host all all 0.0.0.0/0 md5
  - hostssl all all 0.0.0.0/0 md5
  - host replication replicator 0.0.0.0/0 md5
  replication:
    username: replicator
    password: replicator
    network:  127.0.0.1/32
  superuser:
    password: starkandwayne
  admin:
    username: admin
    password: admin
  # wal_e:
  #   env_dir: /home/postgres/etc/wal-e.d/env
  #   threshold_megabytes: 10240
  #   threshold_backup_size_percentage: 30
  restore: /patroni/scripts/restore.py
  # recovery_conf:
  #   restore_command: cp ../wal_archive/%f %p
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
    archive_mode: "on"
    archive_command: mkdir -p ../wal_archive && cp %p ../wal_archive/%f
    archive_timeout: 1800s

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

chown postgres:postgres -R $DATA_DIR /patroni /pgpass /patroni.py
cat /patroni/postgres.yml

sudo -u postgres /scripts/start_pg.sh
