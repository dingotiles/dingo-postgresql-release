Patroni for Cloud Foundry
=========================

This BOSH release deploys a cluster of cells that can run high-availability clustered PostgreSQL. It includes a front-facing routing mesh to route connections the master/solo PostgreSQL node in each cluster.

Many PostgreSQL servers can be run on each cell/server. The solution uses Docker images for package PostgreSQL, and Docker engine to run PostgreSQL in Linux containers.

Clustering between multiple nodes each PostgreSQL cluster is automatically coordinated by https://github.com/zalando/patroni, using etcd backend as a high-availability data store.

If a cell/server is lost, then replicas on other cells are promoted to be the master of each cluster, and the front facing router automatically starts directly traffic to the new master.

Dependencies
------------

This system requires:

-	BOSH or bosh-lite, and the `bosh` CLI installed locally
-	`spruce` CLI to merge YAML files, from http://spruce.cf/
-	a running etcd cluster

### ETCD cluster

This system assumes you have an etcd cluster running.

Why etcd? It is the common demoninator between registrator, patroni and confd. For example, to support consul we would first need to add consul support to patroni. There are also shell scripts now that assume etcd; so they'd need updating or replacing with executable that support different backends.

The templates include an easy way to run an etcd node, if you don't already have an etcd cluster, using [cloudfoundry-incubator/etcd-release](https://github.com/cloudfoundry-incubator/etcd-release). See "Deployment" section for instructions.

If you do already have an etcd cluster then create a spruce stub file with your etcd cluster information, say `tmp/etcd.yml`:

```yaml
---
meta:
  etcd:
    host: 10.244.4.2
  registrator:
    backend_uri: (( concat "etcd://" meta.etcd.host ":4001" ))
```

Deployment
----------

To use your own etcd cluster:

```
./templates/make_manifest warden upstream tmp/etcd.yml
bosh deploy
```

To deploy a simple one-node etcd cluster for demonstration purposes:

```
./templates/make_manifest warden upstream templates/jobs-etcd.yml
bosh deploy
```

Usage
-----

To directly target a Patroni/Docker node's broker and create a container:

```
id=1; broker=10.244.21.6; curl -v -X PUT http://containers:containers@${broker}/v2/service_instances/${id} -d '{"service_id": "0f5c1670-6dc3-11e5-bc08-6c4008a663f0", "plan_id": "1545e30e-6dc3-11e5-826a-6c4008a663f0", "organization_guid": "x", "space_guid": "x"}' -H "Content-Type: application/json"
```

To create replica container on another vm `10.244.21.7`:

```
id=1; broker=10.244.21.7; curl -v -X PUT http://containers:containers@${broker}/v2/service_instances/${id} -d '{"service_id": "0f5c1670-6dc3-11e5-bc08-6c4008a663f0", "plan_id": "1545e30e-6dc3-11e5-826a-6c4008a663f0", "organization_guid": "x", "space_guid": "x"}' -H "Content-Type: application/json"
```

To confirm that the first container is the leader:

```
$ ./scripts/leaders.sh
cf-1 postgres:// 10.244.21.6 30000 postgres
```

Note that `id=1` has become `cf-1`.

Create more container clusters with different `id=123` and you'll see the first container created automatically becomes the leader, thanks to patroni.

Now stop/destroy the VM running the leader of your cluster:

```
bosh -n stop patroni 0
```

Initially the cluster will lose its master:

```
$ ./scripts/leaders.sh
Cluster cf-1 not found or leader not available yet
```

And eventually the follower in the `cf-1` cluster will become the master:

```
$ ./scripts/leaders.sh
cf-1 postgres:// 10.244.21.7 40000 postgres
```

If you restart `patroni/0` vm, the containers will restart and rejoin their clusters.

```
bosh -n start patroni 0
```

You can also watch the status of all nodes in all clusters:

```
watch -n2 ./scripts/service_states.sh
```

Background
----------

### registrator job

This is running a fork of gliderlabs/registrator https://github.com/drnic/registrator/tree/hostname-override that allows use to set the `-hostname` used in the registration. This means we can use BOSH VM information; rather than generic IaaS hostname info. This is especially good for bosh-lite vms which share the same common `hostname`.
