Patroni for Cloud Foundry
=========================

Dependencies
------------

This system requires:

-	BOSH or bosh-lite, and the `bosh` CLI installed locally
-	`spruce` CLI to merge YAML files, from http://spruce.cf/
-	a running etcd cluster

### ETCD cluster

This system assumes you have an etcd cluster running.

For example, try using [cloudfoundry-incubator/etcd-release](https://github.com/cloudfoundry-incubator/etcd-release).

Now create a spruce stub file with your etcd cluster information, say `tmp/etcd.yml`:

```yaml
---
meta:
  etcd:
    host: 10.244.4.2
    port: "4001"
  registrator:
    backend_uri: (( concat "etcd://" meta.etcd.host ":" meta.etcd.port ))
```

Deployment
----------

```
./templates/make_manifest warden upstream tmp/etcd.yml
bosh deploy
```

Usage
-----

To directly target a Patroni/Docker node's broker and create a container:

```
id=1; broker=10.244.22.6; curl -v -X PUT http://containers:containers@${broker}/v2/service_instances/${id} -d '{"service_id": "0f5c1670-6dc3-11e5-bc08-6c4008a663f0", "plan_id": "1545e30e-6dc3-11e5-826a-6c4008a663f0", "organization_guid": "x", "space_guid": "x"}' -H "Content-Type: application/json"
```

To create replica container on another vm `10.244.22.7`:

```
id=1; broker=10.244.22.7; curl -v -X PUT http://containers:containers@${broker}/v2/service_instances/${id} -d '{"service_id": "0f5c1670-6dc3-11e5-bc08-6c4008a663f0", "plan_id": "1545e30e-6dc3-11e5-826a-6c4008a663f0", "organization_guid": "x", "space_guid": "x"}' -H "Content-Type: application/json"
```

To confirm that the first container is the leader:

```
$ ./scripts/leaders.sh
cf-1 postgres:// 10.244.22.6 30000 postgres
```

Note that `id=1` has become `cf-1`.

Create more container clusters with different `id=123` and you'll see the first container created is the leader.

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
cf-1 postgres:// 10.244.22.7 40000 postgres
```

If you restart `patroni/0` vm, the containers will restart and rejoin their clusters.

```
bosh -n start patroni 0
```

Background
----------

### registrator job

This is running a fork of gliderlabs/registrator https://github.com/drnic/registrator/tree/hostname-override that allows use to set the `-hostname` used in the registration. This means we can use BOSH VM information; rather than generic IaaS hostname info. This is especially good for bosh-lite vms which share the same common `hostname`.
