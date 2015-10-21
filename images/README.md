Patroni-enabled PostgreSQL Dockerfile
=====================================

A Dockerfile that produces a Docker image for [PostgreSQL](http://www.postgresql.org/) that includes clustering support via [Patroni](https://github.com/zalando/patroni)

Docker image
------------

### PostgreSQL version

Each subfolder, such as `postgresql94-patroni`, builds the image from a different major PostgreSQL version, such as PG 9.4.

The [postgresql-docker-boshrelease](https://github.com/cloudfoundry-community/postgresql-docker-boshrelease) project currently owns and builds the upstream `cfcommunity/postgresql-base:9.4` images that are used.

### Pull the image

```
docker pull cfcommunity/postgresql-patroni:9.4
```

### Build the image

To create the image `cfcommunity/postgresql-patroni`, execute the following command in the `postgresql94-patroni` folder:

```
$ docker build -t cfcommunity/postgresql-patroni:9.4 .
```

Running a cluster
-----------------

### Host IP

The docker containers do not know their host IP by default, and need it passed into them via command flags or environment variables:

On Linux:

```
HostIP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tail -n1)
```

### Running etcd

There are many production ways to run etcd. In this section we don't follow them at all. Just run it in a container and move on to the next section:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  run -d -p 4001:4001 -p 2380:2380 -p 2379:2379 --name etcd quay.io/coreos/etcd:v2.0.3 \
    -name etcd0 \
    -advertise-client-urls http://${HostIP}:2379,http://${HostIP}:4001 \
    -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
    -initial-advertise-peer-urls http://${HostIP}:2380 \
    -listen-peer-urls http://0.0.0.0:2380 \
    -initial-cluster-token etcd-cluster-1 \
    -initial-cluster etcd0=http://${HostIP}:2380 \
    -initial-cluster-state new
```

Confirm that etcd is running:

```
curl -s localhost:4001/version
{"releaseVersion":"2.0.3","internalVersion":"2"}
```

### Configure your cluster

```
POSTGRES_USERNAME=pgadmin
POSTGRES_PASSWORD=$(pwgen -s -1 16)
```

### Run your first cluster

To run a container, binding to host port 40000:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  run -d --name john -p 40000:5432 \
    -e PATRONI_SCOPE=my_first_cluster \
    -e ETCD_CLUSTER=${HostIP}:4001 \
    -e PORT_5432_TCP=40000 -e HOSTPORT_5432_TCP=${HostIP}:40000 \
    -e POSTGRES_USERNAME=${POSTGRES_USERNAME} \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    cfcommunity/postgresql-patroni:9.4
```

To view the start up logs for the container:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  logs -f john
```

Confirm that the PostgreSQL node is advertising itself in etcd:

```
curl -s localhost:4001/v2/keys/service/my_first_cluster/members | jq ".node.nodes[].value"
"{\"role\":\"master\",\"state\":\"running\",\"conn_url\":\"postgres://replicator:replicator@10.244.20.6:40000/postgres\",\"api_url\":\"http://127.0.0.1:8008/patroni\",\"xlog_location\":23757944}"
```

The `conn_url` can be passed directly to `psql` to confirm we can connect to the server:

```
$ psql postgres://replicator:replicator@10.244.20.6:40000/postgres
psql (9.4.5)
Type "help" for help.

postgres=>
```

### Expand the cluster

To run a second container that joins to the same cluster, binding to host port 40001:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  run -d --name paul -p 40001:5432 \
    -e PATRONI_SCOPE=my_first_cluster \
    -e ETCD_CLUSTER=${HostIP}:4001 \
    -e PORT_5432_TCP=40001 -e HOSTPORT_5432_TCP=${HostIP}:40001 \
    -e POSTGRES_USERNAME=${POSTGRES_USERNAME} \
    -e POSTGRES_USERNAME=${POSTGRES_PASSWORD} \
    cfcommunity/postgresql-patroni:9.4
```

To view the start up logs for the container:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  logs -f paul
```

Confirm the additional container has added itself to the etcd list of members:

```
$ curl -s localhost:4001/v2/keys/service/my_first_cluster/members | jq ".node.nodes[].value"
"{\"role\":\"master\",\"state\":\"running\",\"conn_url\":\"postgres://replicator:replicator@10.244.20.6:40001/postgres\",\"api_url\":\"http://127.0.0.1:8008/patroni\",\"xlog_location\":50332008}"
"{\"role\":\"replica\",\"state\":\"running\",\"conn_url\":\"postgres://replicator:replicator@10.244.20.6:40000/postgres\",\"api_url\":\"http://127.0.0.1:8008/patroni\",\"xlog_location\":50332008}"
```

Confirm that the master has the replica registered:

```
$ psql postgres://replicator:replicator@10.244.20.6:40001/postgres -c 'select * from pg_stat_replication;'
pid | usesysid |  usename   | application_name | client_addr |...
 82 |    16384 | replicator | walreceiver      | 172.17.42.1 |...
```

### Failover the master

In one terminal, tail the replica `paul` logs:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  logs -f paul
```

In another terminal, stop the current master node:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  stop john
```

The replica logs will show that the replication starts failing and eventually patroni automatically promotes the replica to be the master:

```
2015-10-21 22:06:49,068 INFO: no action.  i am a secondary and i am following a leader
FATAL:  could not connect to the primary server: could not connect to server: Connection refused
		Is the server running on host "10.244.20.6" and accepting
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
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  start john
docker --host unix:///var/vcap/sys/run/docker/docker.sock \
  logs -f john
```

The old master will recognize it is no longer the master and will resynchronize itself as a follower:

```
Starting Patroni...
2015-10-21 22:07:37,350 INFO: Starting new HTTP connection (1): 10.244.20.6
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

### Delete cluster

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock rm -f john
docker --host unix:///var/vcap/sys/run/docker/docker.sock rm -f paul
curl -v "localhost:4001/v2/keys/service/my_first_cluster?dir=true&recursive=true" -X DELETE
```

To delete the etcd node:

```
docker --host unix:///var/vcap/sys/run/docker/docker.sock rm -f etcd
```

Copyright
---------

Copyright (c) 2015 Stark & Wayne LLC. See [LICENSE](https://github.com/cloudfoundry-community/patroni-boshrelease/blob/master/LICENSE.md) for details.
