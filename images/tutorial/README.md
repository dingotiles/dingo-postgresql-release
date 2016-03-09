# Helpers to reproduce tutorial faster

This folder contains some helper scripts that match to the series of commands in `images/README.md` tutorial.

### Create first container

To clean out the containers, ALL etcd data, and the S3 backups:

```
env $(cat tmp/tutorial.env| xargs) ./images/tutorial/cleanup.sh; env $(cat tmp/tutorial-wale.env | xargs) ./images/tutorial/cleanup-s3.sh; env_file=tmp/tutorial-wale.env env $(cat tmp/tutorial.env| xargs) NODE_GUID=test-first ./images/tutorial/create.sh
```

This takes a few minutes until the basebackup is complete and new WAL segments archived:

```
wal_e.worker.upload INFO     MSG: begin uploading a base backup volume
        STRUCTURED: time=2016-03-09T22:32:18.528591-00 pid=155
...
wal_e.worker.upload INFO     MSG: finish uploading a base backup volume
        STRUCTURED: time=2016-03-09T22:34:01.778021-00 pid=155
...
NOTICE:  pg_stop_backup complete, all required WAL segments have been archived
2016-03-09 22:34:46,776 INFO: Lock owner: pg_my_first_cluster_test-first; I am pg_my_first_cluster_test-first
```

### Insert data / `pgbench`

The `pgbench.sh` script will lookup the current leader's `conn_url` and run `pgbench` against it:

```
env $(cat tmp/tutorial.env | xargs) ./images/tutorial/pgbench.sh
```

### Delete and restore leader

To delete and recreate a container, and restore from the backup:

```
env_file=tmp/tutorial-wale.env env $(cat tmp/tutorial.env| xargs) NODE_GUID=test-$(uuid) ./images/tutorial/create.sh
```

When successful, the logs include:

```
2016-03-09 22:36:01,057 INFO: trying to bootstrap from leader
...
wal_e.worker.s3.s3_worker INFO     MSG: beginning partition download
        DETAIL: The partition being downloaded is part_00000000.tar.lzo.
        HINT: The absolute S3 key is backups/my_first_cluster/wal/basebackups_005/base_000000010000000000000002_00000040/tar_partitions/part_00000000.tar.lzo.
        STRUCTURED: time=2016-03-09T22:36:09.917971-00 pid=82
```

Eventually finishes with:

```
wal_e.operator.backup INFO     MSG: complete wal restore
        STRUCTURED: time=2016-03-09T22:37:13.290081-00 pid=275 action=wal-fetch key=s3://dingo-postgresql-testflight-backups/backups/my_first_cluster/wal/wal_005/00000001.history.lzo prefix=backups/my_first_cluster/wal/ seg=00000001.history state=complete
LOG:  archive recovery complete
LOG:  MultiXact member wraparound protections are now enabled
LOG:  database system is ready to accept connections
LOG:  autovacuum launcher started
```

It then starts backing up again:

```
wal_e.worker.upload INFO     MSG: begin uploading a base backup volume
        DETAIL: Uploading to "s3://dingo-postgresql-testflight-backups/backups/my_first_cluster/wal/basebackups_005/base_000000020000000000000004_00000040/tar_partitions/part_00000000.tar.lzo".
        STRUCTURED: time=2016-03-09T22:37:40.126567-00 pid=331
...


## Recovering cluster when leader elapsed from etcd

For the above to work:

1. The original cluster needed to successfully upload a basebackup and initial wal logs
2. Minimal time elapsed between leader death and replacement with new replica-cum-leader

If the latter is not true then some leader data in etcd will lapse and patroni will not want to allow a replica to be restored. Don't know why - its something to be investigate in future.

So we need to manufacture the etcd data for a "recently deceased leader".

```
curl -s ${ETCD_CLUSTER}/v2/keys/service/my_first_cluster/leader -XPUT -d 'value=dummy'
curl -s ${ETCD_CLUSTER}/v2/keys/service/my_first_cluster/members/dummy -XPUT -d 'value="{\"conn_url\":\"postgres://replicator:replicator@192.168.99.100:40000/postgres\",\"api_url\":\"http://127.0.0.1:8008/patroni\",\"tags\":{},\"conn_address\":\"192.168.99.100:40000\",\"state\":\"running\",\"role\":\"master\",\"xlog_location\":100663392}"'
{"action":"set","node":{"key":"/service/my_first_cluster/members/dummy","value":"\"{\\\"conn_url\\\":\\\"postgres://replicator:replicator@192.168.99.100:40000/postgres\\\",\\\"api_url\\\":\\\"http://127.0.0.1:8008/patroni\\\",\\\"tags\\\":{},\\\"conn_address\\\":\\\"192.168.99.100:40000\\\",\\\"state\\\":\\\"running\\\",\\\"role\\\":\\\"master\\\",\\\"xlog_location\\\":100663392}\"","modifiedIndex":11751,"createdIndex":11751}
```
