#Quickstart with docker-compose

This is a very quick demonstration to see a postgresql-patroni cluster in action.

## Dependencies

If you don't already have `docker` & `docker-compose` installed, then for OS X you can install them with homebrew:

```
brew install docker-compose
```

## Services

[docker-compose.yml](./docker-compose.yml) defines the services introduced in the (README tutorial)(./README.md).

* `john` and `paul` are going to make up a 2 node postgresql-patroni cluster
* `etcd` and `registrator` are backing services required to get everything running

See the README.md for formal introduction to each of these containers and their purpose.

## Quick intro

Setup an environment variable so that the variables can be passed to the cluster properly.

```
export HOST_IP=$(docker-machine ip)
echo $HOST_IP
```

Then bring up the cluster:

```
docker-compose up -d
docker-compose ps
docker-compose logs
```

You will see all containers start. Either `john` or `paul` will be elected leader you can play around with what happens if one of them fails and rejoins by doing:

```
docker-compose stop john
docker-compose logs paul
docker-compose start john
docker-compose logs
```

## Backups

To enable backups uncomment the lines in [wal-e-example.env](./wal-e-example.env) and enter appropriate aws creds as well as a bucket. Restart the cluster:

```
docker-compose down
docker-compose up -d
docker-compose logs
```

and run `pg_bench`
```
pgbench -i postgres://john:johnpass@${HOST_IP}:40000/postgres
pgbench postgres://john:johnpass@${HOST_IP}:40000/postgres -T 60
```
