PostgreSQL Dockerfile
=====================

A Dockerfile that produces a Docker Image for [PostgreSQL](http://www.postgresql.org/).

It is imported from https://github.com/cfcommunity/docker-postgresql

PostgreSQL version
------------------

The `master` branch currently hosts PostgreSQL 9.4.

Different versions of PostgreSQL are located at the github repo [branches](https://github.com/cfcommunity/docker-postgresql/branches).

Usage
-----

### Build the image

To create the image `cfcommunity/postgresql-patroni`, execute the following command in the `postgresql94-patroni` folder:

```
$ docker build -t cfcommunity/postgresql-patroni:9.4 .
```

### Host IP

The docker containers do not know their host IP by default, and need it passed into them via command flags or environment variables:

On Linux:

```
HostIP=$(/sbin/ip route|awk '/default/ { print $3 }')
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
    -e POSTGRES_USERNAME=${POSTGRES_PASSWORD} \
    cfcommunity/postgresql-patroni:9.4
```

To view the start up logs for the container:

```
docker logs john
```

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

You will see an output like the following:

```
========================================================================
PostgreSQL User: "pgadmin"
PostgreSQL Password: "WH7fwqY7bJCEMYKC"
========================================================================
```

#### Credentials

If you want to preset credentials instead of a random generated ones, you can set the following environment variables:

-	`POSTGRES_USERNAME` to set a specific username
-	`POSTGRES_PASSWORD` to set a specific password

On this example we will preset our custom username and password:

```
$ docker run -d \
    --name postgresql \
    -p 5432:5432 \
    -e POSTGRES_USERNAME=myuser \
    -e POSTGRES_PASSWORD=mypassword \
    cfcommunity/postgresql
```

#### Databases

If you want to create a database at container's boot time, you can set the following environment variables:

-	`POSTGRES_DBNAME` to create a database
-	`POSTGRES_EXTENSIONS` to create extensions for the above database (only takes effect is a database is specified)

On this example we will preset our custom username and password and we will create a database with a extension:

```
$ docker run -d \
    --name postgresql \
    -p 5432:5432 \
    -e POSTGRES_USERNAME=myuser \
    -e POSTGRES_PASSWORD=mypassword \
    -e POSTGRES_DBNAME=mydb \
    -e POSTGRES_EXTENSIONS=citext \
    cfcommunity/postgresql
```

#### Persist database data

The PostgreSQL server is configured to store data in the `/data` directory inside the container. You can map the container's `/data` volume to a volume on the host so the data becomes independent of the running container:

```
$ mkdir -p /tmp/postgresql
$ docker run -d \
    --name postgresql \
    -p 5432:5432 \
    -v /tmp/postgresql:/data \
    cfcommunity/postgresql
```

Copyright
---------

Copyright (c) 2014 Ferran Rodenas. See [LICENSE](https://github.com/cfcommunity/docker-postgresql/blob/master/LICENSE) for details.
