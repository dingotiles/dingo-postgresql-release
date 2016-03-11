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

You will see all containers start, a leader be elected (probably `john` as it is started first), and the follower start replicating from the leader.

You can run `pg_bench` against which PostgreSQL container is currently leader (either port 40000 for `john` or 40001 for `paul`):

```
pg_uri=postgres://john:johnpass@${HOST_IP}:40000/postgres
pgbench -i ${pg_uri}
pgbench ${pg_uri} -T 60
psql ${pg_uri} -c '\dt;'
psql ${pg_uri} -c 'select * from pgbench_tellers;'
```

You can play around with what happens if the leader (say its currently `john`) fails:

```
docker-compose stop john
docker-compose logs paul
docker-compose start john
docker-compose logs
```

You will notice that `paul` eventually realises that `john` isn't coming back and becomes the leader. When `john` returns, it recognizes that it is no longer the leader and reinitializes itself as a replica.

To confirm that the data is replicated to the replica-cum-leader `paul`:

```
pg_uri=postgres://john:johnpass@${HOST_IP}:40001/postgres
psql ${pg_uri} -c 'select * from pgbench_tellers;'
```

## Backups

To enable backups uncomment the lines in [wal-e-example.env](./wal-e-example.env) and enter appropriate aws creds as well as a bucket. Restart the cluster:

```
docker-compose down
docker-compose up -d
docker-compose logs
```
