#Quickstart with docke-compose

This is a very quick demonstration to see this in action quickly.

## Dependencies

`brew install docker-compose`

## Services

[docker-compose.yml](./docker-compose.yml) has a number of services defined. 4 in total `john` and `paul` are going to make up a 2 node postgresql-patroni cluster. `etcd` and `registrator` are backing services required to get everything running.

## Quick intro
You need to
```
export HOST_IP=$(docker-machine ip)
```
So that the variables can be passed to the cluster properly.

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
```

and run `pg_bench`
```
pgbench -i postgres://john:johnpass@${HOST_IP}:40000/postgres
pgbench postgres://john:johnpass@${HOST_IP}:40000/postgres -T 60
docker-compose logs john
```
