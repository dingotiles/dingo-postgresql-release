Patroni-enabled PostgreSQL Dockerfile
=====================================

A Dockerfile that produces a Docker image for [PostgreSQL](http://www.postgresql.org/) that includes clustering support via [Patroni](https://github.com/zalando/patroni)

Tutorial to learn and play
--------------------------

### Dependencies

Linux:

```
apt-get install jq
```

Mac:

```
brew install jq
```

### Docker command

If you are running this tutorial on a Docker VM managed by docker-boshrelease:

```
export PATH=/var/vcap/packages/docker/bin:$PATH
docker_sock=/var/vcap/sys/run/docker/docker.sock
alias _docker="docker --host unix://${docker_sock}"
```

If standard `docker --host`, say via docker-machine, then:

```
docker_sock=/var/run/docker.sock
alias _docker="docker"
```

### PostgreSQL version

Each subfolder, such as `postgresql95-patroni`, builds the image from a different major PostgreSQL version, such as PG 9.5.

The [postgresql-docker-boshrelease](https://github.com/cloudfoundry-community/postgresql-docker-boshrelease) project currently owns and builds the upstream `cfcommunity/postgresql-base:9.5` images that are used.

Setup the environment variable used in the rest of the tutorial:

```
postgresql_image=cfcommunity/postgresql-patroni:9.5
```

### Pull the image

```
_docker pull ${postgresql_image}
```

### Build the image

To create the image `cfcommunity/postgresql-patroni`, execute the following command in the `postgresql95-patroni` folder:

```
git clone https://github.com/drnic/patroni -b connect_address_20150308 postgresql95-patroni/patroni
docker build -t ${postgresql_image} postgresql95-patroni
```

Running a cluster
-----------------

### Host IP

The docker containers do not know their host IP by default, and need it passed into them via command flags or environment variables:

On Linux:

```
HostIP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tail -n1)
```

On `docker-machine`:

```
HostIP=$(docker-machine ip default)
```

### Running etcd

There are many production ways to run etcd. In this section we don't follow them at all. Just run it in a container and move on to the next section:

```
_docker rm -f etcd
_docker run -d -p 4001:4001 -p 2380:2380 -p 2379:2379 --name etcd quay.io/coreos/etcd:v2.0.3 \
    -name etcd0 \
    -advertise-client-urls "http://${HostIP}:2379,http://${HostIP}:4001" \
    -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
    -initial-advertise-peer-urls "http://${HostIP}:2380" \
    -listen-peer-urls http://0.0.0.0:2380 \
    -initial-cluster-token etcd-cluster-1 \
    -initial-cluster "etcd0=http://${HostIP}:2380" \
    -initial-cluster-state new
_docker logs etcd
```

Set an env var to document where one of the etcd nodes is located:

```
ETCD_CLUSTER=${HostIP}:4001
```

Confirm that etcd is running:

```
curl -s ${ETCD_CLUSTER}/version
{"releaseVersion":"2.0.3","internalVersion":"2"}
```

### Running registrator

Containers do not know their own public host:port information. In our solution we use [registrator](https://github.com/gliderlabs/registrator) (currently a forked version with [PR #280](https://github.com/gliderlabs/registrator/pull/280)\).

```
_docker rm -f registrator
_docker run -d --name registrator \
    --net host \
    --volume ${docker_sock}:/tmp/docker.sock \
  cfcommunity/registrator:latest /bin/registrator \
    -hostname ${HostIP} -ip ${HostIP} \
  etcd://${ETCD_CLUSTER}
_docker logs registrator
```

The logs from registrator will show that the `etcd` container is advertising 3 ports:

```
2015/11/23 16:02:05 added: 3f84b7858bed 192.168.99.100:etcd:2380
2015/11/23 16:02:05 added: 3f84b7858bed 192.168.99.100:etcd:4001
2015/11/23 16:02:05 added: 3f84b7858bed 192.168.99.100:etcd:2379
```

Later, registrator will advertise the ports of all the PostgreSQL/Patroni containers, allowing them each to self-discover their public host:port information.

### Configure your cluster

```
sudo apt-get install pwgen
POSTGRES_USERNAME=pgadmin
POSTGRES_PASSWORD=$(pwgen -s -1 16)
```

On Mac OS X:

```
brew install pwgen
POSTGRES_USERNAME=pgadmin
POSTGRES_PASSWORD=$(pwgen -s -1 16)
```

### Run your first cluster

To run a container, binding to host port 40000:

```
_docker rm -f john
_docker run -d \
    --name john -p 40000:5432 \
    -e NAME=john \
    -e PATRONI_SCOPE=my_first_cluster \
    -e "ETCD_HOST_PORT=${ETCD_CLUSTER}" \
    -e "DOCKER_HOSTNAME=${HostIP}" \
    -e "POSTGRES_USERNAME=${POSTGRES_USERNAME}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    ${postgresql_image}
```

To view the start up logs for the container:

```
_docker logs -f john
...
2015-11-23 16:24:13,464 INFO: established a new patroni connection to the postgres cluster
2015-11-23 16:24:13,481 INFO: initialized a new cluster
```

Cancel `docker logs -f` with Ctrl-C.

To confirm that registrator is advertising the container's 5432 port:

```
_docker logs registrator
...
2015/11/23 16:04:45 added: 47d12377ffe2 192.168.99.100:john:5432
```

Also confirm registrator is advertising into etcd:

```
curl -s ${ETCD_CLUSTER}/v2/keys/postgresql-patroni\?recursive=true | jq .
{
  "action": "get",
  "node": {
    "key": "/postgresql-patroni",
    "dir": true,
    "nodes": [
      {
        "key": "/postgresql-patroni/192.168.99.100:john:5432",
        "value": "192.168.99.100:40000",
        "modifiedIndex": 47,
        "createdIndex": 47
      }
    ],
    "modifiedIndex": 9,
    "createdIndex": 9
  }
}
```

Confirm that the PostgreSQL node is advertising itself in etcd:

```
curl -s ${ETCD_CLUSTER}/v2/keys/service/my_first_cluster/members | jq -r ".node.nodes[].value" | jq .
{
  "conn_url": "postgres://replicator:replicator@10.244.21.6:40000/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "tags": {},
  "conn_address": "192.168.99.100:40000",
  "state": "running",
  "role": "master",
  "xlog_location": 23758288
}
```

The `conn_address` field is from unmerged patroni [PR #91](https://github.com/zalando/patroni/pull/91); and is used by the routing tier to easily get the `host:port` information (it cannot easily parse the `conn_url` field).

The `conn_url` can be passed directly to `psql` or using the admin username password we can confirm we can connect to the server using credentials above:

```
$ psql postgres://replicator:replicator@10.244.21.6:40000/postgres
psql (9.5.1)
Type "help" for help.

postgres=>
$ psql postgres://${POSTGRES_USERNAME}:${POSTGRES_PASSWORD}@10.244.21.6:40000/postgres
psql (9.5.1)
Type "help" for help.

postgres=>
```

### Expand the cluster

To run a second container that joins to the same cluster, binding to host port 40001:

```
_docker rm -f paul
_docker run -d --name paul -p 40001:5432 \
    -e NAME=paul \
    -e PATRONI_SCOPE=my_first_cluster \
    -e "ETCD_HOST_PORT=${ETCD_CLUSTER}" \
    -e "DOCKER_HOSTNAME=${HostIP}" \
    -e POSTGRES_USERNAME=${POSTGRES_USERNAME} \
    -e POSTGRES_USERNAME=${POSTGRES_PASSWORD} \
    ${postgresql_image}
```

To view the start up logs for the container:

```
_docker logs -f paul
...
2015-11-23 16:27:56,708 INFO: bootstrapped from leader
2015-11-23 16:28:01,072 INFO: established a new patroni connection to the postgres cluster
2015-11-23 16:28:01,090 INFO: Lock owner: pg_172_17_0_17; I am pg_172_17_0_18
2015-11-23 16:28:01,090 INFO: does not have lock
2015-11-23 16:28:01,091 INFO: no action.  i am a secondary and i am following a leader
```

Confirm the additional container has added itself to the etcd list of members:

```
curl -s ${ETCD_CLUSTER}/v2/keys/service/my_first_cluster/members | jq -r ".node.nodes[].value" | jq .
{
  "conn_url": "postgres://replicator:replicator@10.244.21.6:40000/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "tags": {},
  "conn_address": "10.244.21.6:40000",
  "state": "running",
  "role": "master",
  "xlog_location": 50331744
}
{
  "conn_url": "postgres://replicator:replicator@10.244.21.6:40001/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "tags": {},
  "conn_address": "10.244.21.6:40001",
  "state": "running",
  "role": "replica",
  "xlog_location": 50331744
}
```

Confirm that the master has the replica registered:

```
$ psql postgres://replicator:replicator@${HostIP}:40000/postgres -c 'select * from pg_stat_replication;'
pid | usesysid |  usename   | application_name | client_addr |...
 82 |    16384 | replicator | walreceiver      | 172.17.42.1 |...
```

### Failover the master

In one terminal, tail the replica `paul` logs:

```
_docker logs -f paul
```

In another terminal, stop the current master node:

```
_docker stop john
```

The replica logs will show that the replication starts failing and eventually patroni automatically promotes the replica to be the master:

```
2015-10-21 22:06:49,068 INFO: no action.  i am a secondary and i am following a leader
FATAL:  could not connect to the primary server: could not connect to server: Connection refused
		Is the server running on host "10.244.21.6" and accepting
		TCP/IP connections on port 40000?
...
ConnectionError: HTTPConnectionPool(host='127.0.0.1', port=8008): Max retries exceeded with url: /patroni (Caused by <class 'httplib.BadStatusLine'>: '')
server promoting
LOG:  received promote request
LOG:  redo done at 0/3000028
2015-10-21 22:06:58,572 INFO: cleared rewind flag after becoming the leader
2015-10-21 22:06:58,572 INFO: promoted self to leader by acquiring session lock
LOG:  selected new timeline ID: 2
LOG:  archive recovery complete
LOG:  MultiXact member wraparound protections are now enabled
LOG:  autovacuum launcher started
LOG:  database system is ready to accept connections
2015-10-21 22:07:08,452 INFO: Lock owner: postgresql_172_17_0_63; I am postgresql_172_17_0_63
2015-10-21 22:07:08,463 INFO: no action.  i am the leader with the lock
```

`paul` is now the master of the cluster (of 1 node)

### Restore the old master

The old master can be restarted (representing the healing of a network partition or return of the node during some downtime):

```
_docker start john
_docker logs -f john
```

The old master will recognize it is no longer the master and will resynchronize itself as a follower:

```
Starting Patroni...
2015-10-21 22:07:37,350 INFO: Starting new HTTP connection (1): 10.244.21.6
2015-10-21 22:07:37,391 WARNING: Postgresql is not running.
2015-10-21 22:07:37,391 INFO: Lock owner: postgresql_172_17_0_63; I am postgresql_172_17_0_64
2015-10-21 22:07:37,425 INFO: Removed /data/postgres0/postmaster.pid
waiting for server to start....LOG:  database system was interrupted; last known up at 2015-10-21 22:05:37 UTC
LOG:  entering standby mode
LOG:  database system was not properly shut down; automatic recovery in progress
LOG:  redo starts at 0/2000060
LOG:  record with zero length at 0/3000060
LOG:  consistent recovery state reached at 0/3000060
LOG:  database system is ready to accept read only connections
LOG:  fetching timeline history file for timeline 2 from primary server
LOG:  started streaming WAL from primary at 0/3000000 on timeline 1
LOG:  replication terminated by primary server
DETAIL:  End of WAL reached on timeline 1 at 0/3000060.
LOG:  new target timeline is 2
LOG:  restarted WAL streaming at 0/3000000 on timeline 2
 done
server started
2015-10-21 22:07:38,463 INFO: started as a secondary
2015-10-21 22:07:38,466 INFO: established a new patroni connection to the postgres cluster
```

Delete cluster
--------------

```
_docker rm -f john
_docker rm -f paul
curl -v "${ETCD_CLUSTER}/v2/keys/service?dir=true&recursive=true" -X DELETE
```

To delete the helper processes:

```
_docker rm -f etcd
_docker rm -f registrator
```

Backup/restore from AWS
-----------------------

Patroni supports [wal-e](https://github.com/wal-e/wal-e) for continuous archiving of PostgreSQL WAL files and base backups.

To setup wal-e we need to pass in some environment variables to the Docker containers.

-	`WALE_ENV_DIR` - directory where WAL-E environment is kept
-	`WAL_S3_BUCKET` - a name of the S3 bucket for WAL-E
-	`WALE_BACKUP_THRESHOLD_MEGABYTES` - if WAL amount is above that - use pg_basebackup
-	`WALE_BACKUP_THRESHOLD_PERCENTAGE` - if WAL size exceeds a certain percentage of the latest backup size
-	`AWS_ACCESS_KEY_ID` - AWS access key
-	`AWS_SECRET_ACCESS_KEY` - AWS secret key

For example, create a local file `tmp/wal-e.env` which will be passed into `docker run`:

```
AWS_ACCESS_KEY_ID=XXX
AWS_SECRET_ACCESS_KEY=YYY

WAL_S3_BUCKET=ZZZ
WALE_S3_ENDPOINT=https+path://s3.amazonaws.com:443
#WALE_S3_ENDPOINT=https+path://s3-us-west-2.amazonaws.com:443

WALE_ENV_DIR=/data/wal-e/env
WALE_BACKUP_THRESHOLD_PERCENTAGE=30
WALE_BACKUP_THRESHOLD_MEGABYTES=10240
```

Now, when invoking `docker run` above, include this `/tmp/wal-e.env` file:

```
_docker rm -f john
_docker rm -f paul
curl -v "${ETCD_CLUSTER}/v2/keys/service?dir=true&recursive=true" -X DELETE

_docker run -d --name john -p 40000:5432 \
    --env-file=tmp/wal-e.env \
    -e NAME=john \
    -e PATRONI_SCOPE=my_first_cluster \
    -e "ETCD_HOST_PORT=${ETCD_CLUSTER}" \
    -e "DOCKER_HOSTNAME=${HostIP}" \
    -e "POSTGRES_USERNAME=${POSTGRES_USERNAME}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    ${postgresql_image}
_docker logs -f john
```

After PostgreSQL creates the initial database, the first backup and first wal segement will be taken and uploaded to your S3 bucket:

```
wal_e.worker.base INFO     MSG: Not deleting any data.
        DETAIL: No existing base backups.
        STRUCTURED: time=2015-11-23T22:19:03.033284-00 pid=150
producing a new backup at Mon Nov 23 22:19:03 UTC 2015
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "backup-push".
        STRUCTURED: time=2015-11-23T22:19:03.144693-00 pid=157
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "wal-push".
        STRUCTURED: time=2015-11-23T22:19:03.333521-00 pid=167
wal_e.worker.upload INFO     MSG: begin archiving a file
        DETAIL: Uploading "pg_xlog/000000010000000000000001" to "s3://patroni-demo/backups/my_first_cluster/wal/wal_005/000000010000000000000001.lzo".
        STRUCTURED: time=2015-11-23T22:19:03.422584-00 pid=167 action=push-wal key=s3://patroni-demo/backups/my_first_cluster/wal/wal_005/000000010000000000000001.lzo prefix=backups/my_first_cluster/wal/ seg=000000010000000000000001 state=begin
wal_e.operator.backup INFO     MSG: start upload postgres version metadata
        DETAIL: Uploading to s3://patroni-demo/backups/my_first_cluster/wal/basebackups_005/base_000000010000000000000002_00000040/extended_version.txt.
        STRUCTURED: time=2015-11-23T22:19:03.650981-00 pid=157
```

To add some data to trigger the initial WAL pushes:

```
pgbench -i postgres://replicator:replicator@192.168.99.100:40000/postgres
pgbench postgres://replicator:replicator@192.168.99.100:40000/postgres -T 60
_docker logs -f john
```

The logs will show that a new wal segment is uploaded:

```
wal_e.main   INFO     MSG: starting WAL-E
        DETAIL: The subcommand is "wal-push".
        STRUCTURED: time=2015-11-23T22:23:33.266677-00 pid=541
wal_e.worker.upload INFO     MSG: begin archiving a file
        DETAIL: Uploading "pg_xlog/000000010000000000000003" to "s3://patroni-demo/backups/my_first_cluster/wal/wal_005/000000010000000000000003.lzo".
        STRUCTURED: time=2015-11-23T22:23:33.340118-00 pid=541 action=push-wal key=s3://patroni-demo/backups/my_first_cluster/wal/wal_005/000000010000000000000003.lzo prefix=backups/my_first_cluster/wal/ seg=000000010000000000000003 state=begin
LOG:  unexpected EOF on client connection with an open transaction
```

Now run secondary `paul`:

```
_docker rm -f paul
_docker run -d --name paul -p 40001:5432 \
    --env-file=tmp/wal-e.env \
    -e NAME=paul \
    -e PATRONI_SCOPE=my_first_cluster \
    -e "ETCD_HOST_PORT=${ETCD_CLUSTER}" \
    -e "DOCKER_HOSTNAME=${HostIP}" \
    -e "POSTGRES_USERNAME=${POSTGRES_USERNAME}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    ${postgresql_image}
_docker logs -f paul
```

Copyright
---------

Copyright (c) 2015 Dr Nic Williams. See [LICENSE](https://github.com/drnic/patroni-docker-boshrelease/blob/master/LICENSE.md) for details.
