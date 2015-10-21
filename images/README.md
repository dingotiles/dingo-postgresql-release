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
    -e PATRONI_SCOPE=my-first-cluster \
    -e ETCD_CLUSTER=${HostIP}:4001 \
    -e PORT_5432_TCP=40000 -e HOSTPORT_5432_TCP=${HostIP}:40000 \
    -e POSTGRES_USERNAME=${POSTGRES_USERNAME} \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    cfcommunity/postgresql-patroni:9.4
```

To view the start up logs for the container:

```
docker logs john
```

Confirm that the PostgreSQL node is advertising itself in etcd:

```
curl -s localhost:4001/v2/keys/service/my-first-cluster/members | jq ".node.nodes[].value"
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
    -e PATRONI_SCOPE=my-first-cluster \
    -e ETCD_CLUSTER=${HostIP}:4001 \
    -e PORT_5432_TCP=40001 -e HOSTPORT_5432_TCP=${HostIP}:40001 \
    -e POSTGRES_USERNAME=${POSTGRES_USERNAME} \
    -e POSTGRES_USERNAME=${POSTGRES_PASSWORD} \
    cfcommunity/postgresql-patroni:9.4
```

To view the start up logs for the container:

```
docker logs paul
```

Copyright
---------

Copyright (c) 2015 Stark & Wayne LLC. See [LICENSE](https://github.com/cloudfoundry-community/patroni-boshrelease/blob/master/LICENSE.md) for details.
