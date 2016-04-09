# High-Availability PostgreSQL for Cloud Foundry

This BOSH release deploys a cluster of cells that can run high-availability clustered PostgreSQL. It includes a front-facing routing mesh to route connections the master/solo PostgreSQL node in each cluster.

Many PostgreSQL servers can be run on each cell/server. The solution uses Docker images for package PostgreSQL, and Docker engine to run PostgreSQL in isolated Linux containers.

Clustering between multiple nodes each PostgreSQL cluster is automatically coordinated by https://github.com/zalando/patroni, using etcd backend as a high-availability data store.

If a cell/server is lost, then replicas on other cells are promoted to be the master of each cluster, and the front facing router automatically starts directly traffic to the new master.

Refer to the [LEARNING_PATRONI](./LEARNING_PATRONI.md) guide for more information patroni.
Dependencies
------------

This system requires:

-	BOSH or bosh-lite, and the `bosh` CLI installed locally
-	`spruce` CLI to merge YAML files, from http://spruce.cf/
-	a running etcd cluster

Deployment
----------

Upload some dependent BOSH releases to your BOSH:

```
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/route-registrar-boshrelease
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/simple-remote-syslog-boshrelease
```

To use your own etcd cluster:

```
./templates/make_manifest warden upstream templates/services-cluster.yml tmp/etcd.yml
bosh deploy
```

To deploy a simple one-node etcd cluster for demonstration purposes:

```
./templates/make_manifest warden upstream templates/services-cluster.yml templates/jobs-etcd.yml
bosh deploy
```

### ETCD cluster

This system assumes you have an etcd cluster running.

Why etcd? It is the common denominator between registrator, patroni and confd. For example, to support consul we would first need to add consul support to patroni. There are also shell scripts now that assume etcd; so they'd need updating or replacing with executable that support different backends.

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

### Remote syslog

To ship logs to a remote syslog endpoint, create a YAML file like below:

```yaml
---
properties:
  remote_syslog:
    address: logs.papertrailapp.com
    port: 54321
    short_hostname: true
  docker:
    log_driver: syslog
    log_options:
    - (( concat "syslog-address=udp://" properties.remote_syslog.address ":" properties.remote_syslog.port ))
    - tag="{{.Name}}"
```

Then include the file in your `make_manifest` command to build your BOSH deployment manifest.

```
./templates/make_manifest warden upstream templates/services-cluster.yml templates/jobs-etcd.yml \
  tmp/syslog.yml
bosh deploy
```

### Streaming backups to AWS S3

Each PostgreSQL master container can continuously stream its write-ahead logs (WAL) to AWS S3. These can later be used to restore master nodes and to create replica nodes.

To enable it requires only passing in some environment variables to the Docker containers, and Patroni will use them to enable continuous archiving via [wal-e](https://github.com/wal-e/wal-e).

See [templates/services-cluster-backup-s3.yml](https://github.com/dingotiles/dingo-postgresql-release/blob/master/templates/services-cluster-backup-s3.yml#L33-L39) for an example of the environment variables required.

To explore how this is implemented within the Docker image, see [image tutorial](https://github.com/dingotiles/dingo-postgresql-release/tree/master/images#backuprestore-from-aws).

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

### Logs for a service instance

During development I've been sending logs to [Papertrail](https://papertrailapp.com), see "Remote logging" section above for setup.

To quickly view all the logs associated with a Cloud Foundry service instance, there is a helper script:

```
export ETCD_CLUSTER=10.10.5.10:4001
export BASE_PAPERTRAIL=https://papertrailapp.com/groups/688143

cf t -o ORG -s SPACE
cf cs postgresql94 cluster testpg
./scripts/papertrail.sh testpg
```

This will display a URL which includes the 3 GUIDs involved in the 2-node service cluster - the Cloud Foundry service instance GUID, and the GUIDs for the two backend containers:

```
https://papertrailapp.com/groups/688143/events?q=(5c743376-3cc2-448e-a8c9-6ca159e58e36+OR+4efe0ab2-a5cb-4711-b318-d5fed22d9398+OR+6333ede0-88d2-4ba8-8da6-e60e3a4a3b9e)
```

Background
----------

### registrator job

This is running a fork of gliderlabs/registrator https://github.com/drnic/registrator/tree/hostname-override that allows use to set the `-hostname` used in the registration. This means we can use BOSH VM information; rather than generic IaaS hostname info. This is especially good for bosh-lite vms which share the same common `hostname`.
