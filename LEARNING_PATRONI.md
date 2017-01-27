#Getting Started
This is a guide to help you getting started with postgres replication with patroni

## Postgres replication basics:
[Ten Minutes To Replication](https://www.youtube.com/watch?v=BD7i9QImqic) is a good introduction to streaming replication with PG.

## Patroni
[Here is  talk](https://www.youtube.com/watch?v=OH9WSEiMsAw) that gives an introduction to patroni.

### Setup

```
git clone git@github.com:zalando/patroni.git
cd patroni
python setup.py install
which patroni
```

Running tests:
```
python setup.py test
```
or:
```
pip install pytest
python -m pytest
```

### Starting a first instance

In case you don't have etcd installed: `brew install etcd`

`etcd --data-dir=data/etcd ` starts etcd (do this in another console).
```
ETCD_CLUSTER=localhost:2379
curl -s ${ETCD_CLUSTER}/version
{"etcdserver":"2.3.7","etcdcluster":"2.2.0"}
cusl -s ${ETCD_CLUSTER}/v2/keys
{"action":"get","node":{"dir":true}}
```
etcd is up and nothing has been written so far.

Lets start up our first patroni/pg instance
```
./patroni.py postgres0.yml
```

Patroni will initialze a PG instance and constantly reconfigure itself according to state observed in the etcd store. The logic it follows for dynamic configuration is nicely viewable in [this diagram](https://github.com/zalando/patroni/blob/master/postgres-ha.pdf).

All shared state is stored in etcd under `/v2/keys/service/<scope>/` where scope is defined in the postgres0.yml file (in this case `batman`).

`curl -s ${ETCD_CLUSTER}/v2/keys/service/batman | jq ` will show you the list of keys:

| key | usage |
| --- | ----- |
| `/service/batman/members` | List all members of the cluster |
| `/service/batman/initialize` | The sysid of the pg instance that initialized the cluster |
| `/service/batman/leader` | The current cluster leader (will be `postgresql0`)|
| `/service/batman/optime` | The uptime of the current leader (under `/service/batman/optime/leader`) |

Looking up information for a member reveals information for that node including how to connect to it.
```
curl -s ${ETCD_CLUSTER}/v2/keys/service/batman/members/postgresql0 | jq -r '.node.value' | jq
{
  "conn_url": "postgres://dvw7DJgqzFBJC8:jkT3TTNebfrh6C@127.0.0.1:5432/postgres",
  "api_url": "http://127.0.0.1:8008/patroni",
  "tags": {
    "nofailover": false,
    "noloadbalance": false,
    "clonefrom": false
  },
  "state": "running",
  "role": "master",
  "xlog_location": 100664512
}
```

We can connect to the database with the `conn_url`:

```
psql postgres://dvw7DJgqzFBJC8:jkT3TTNebfrh6C@127.0.0.1:5432/postgres
psql (9.5.1)
Type "help" for help.

postgres=> \du
                                  List of roles
Role name  |                         Attributes                         | Member of
------------+------------------------------------------------------------+-----------
admin      | Create role, Create DB                                     | {}
postgres   | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
replicator | Replication                                                | {}

postgres=> \q
```

The `api_url` is where you can find patronis own API that allows you to find out information about the running pg instance and interact with it.
```
PATRONI_API=http://127.0.0.1:8008
curl -s ${PATRONI_API}/patroni | jq
{
  "state": "running",
    "role": "master",
    "postmaster_start_time": "2016-03-04 14:03:40.788 CET",
    "tags": {
      "nofailover": false,
      "noloadbalance": false,
      "clonefrom": false
    },
    "xlog": {
      "location": 24341216
    },
    "server_version": 90501
}

curl ${PATRONI_API}/restart -X POST
restarted successfully

curl ${PATRONI_API}/reinitialize -X POST
I am the leader, can not reinitialize
```

### Replication

To test replication lets add another instance to our cluster:
```
./patroni.py postgres1.yml
```
See all members of the cluster
```
curl -s ${ETCD_CLUSTER}/v2/keys/service/batman/members | jq
```
Test if replication is working:
```
psql postgres://admin:admin@127.0.0.1:5432/postgres -c 'select * from pg_stat_replication;'
(1 row)
psql postgres://admin:admin@127.0.0.1:5432/postgres -c 'create table test(test text);'
CREATE TABLE

psql postgres://admin:admin@127.0.0.1:5433/postgres -c '\dt'
(1 row)
```
