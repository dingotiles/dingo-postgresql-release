#!/bin/bash

DATA_DIR=/data
mkdir -p $DATA_DIR
chown postgres:postgres $DATA_DIR

touch /pgpass
chown postgres:postgres -R /patroni/ /data/ /pgpass

# determine host:port to advertise into etcd for replication
if [[ "${HOSTPORT_5432_TCP}X" != "X" ]]; then
  CONNECT_ADDRESS=${HOSTPORT_5432_TCP}
fi
CONNECT_ADDRESS=${CONNECT_ADDRESS:-${DOCKER_IP}:5432}

# TODO secure the passwords!

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
  name: postgresql_${PATRONI_SCOPE} ## Replication slots do not allow dots in their name
  scope: *scope
  listen: 0.0.0.0:5432
  connect_address: ${CONNECT_ADDRESS}
  data_dir: /data/postgres0
  maximum_lag_on_failover: 1048576 # 1 megabyte in bytes
  pg_hba:
  - host all all 0.0.0.0/0 md5
  - hostssl all all 0.0.0.0/0 md5
  - host replication replicator ${DOCKER_IP}/16    md5
  replication:
    username: replicator
    password: replicator
    network:  127.0.0.1/32
  superuser:
    password: starkandwayne
  restore: patroni/scripts/restore.py
  admin:
    username: admin
    password: admin
  parameters:
    archive_mode: "on"
    wal_level: hot_standby
    archive_command: mkdir -p ../wal_archive && cp %p ../wal_archive/%f
    max_wal_senders: 20
    listen_addresses: 0.0.0.0
    wal_keep_segments: 8
    archive_timeout: 1800s
    max_replication_slots: 20
    hot_standby: "on"
__EOF__

cat /patroni/postgres.yml

echo "Starting Patroni..."
# /data/postgresql0 was missing - where is it supposed to be?
# I don't think patroni, and thus initdb, has rights to initdb
# perhaps run.sh is run as root; and the patroni.sh invokes python?
# To initdb I had to:
# sudo -u postgres /usr/lib/postgresql/9.4/bin/pg_ctl -w -D /data/postgresql0 initdb -o --encoding=UTF8
sudo -u postgres python /patroni/patroni.py /patroni/postgres.yml
