# Dingo PostgreSQL for Cloud Foundry

Allow your Cloud Foundry users to provision High-Availability PostgreSQL clusters, backed by a disaster recovery system with maximum 10 minutes data loss.

```
cf create-service dingo-postgresql cluster my-first-db
cf bind-service myapp my-first-db
cf restart myapp
```

The BOSH release is the basis for the Pivotal Network tile [Dingo PostgreSQL](http://www.dingotiles.com/dingo-postgresql/) and uses the same licensing system for commercial customers. As the [Licensing](#licensing) system applies to both this OSS BOSH release and the Pivotal tile, we are distributing all product features, support tooling, and documentation in both distributions.

![dingo-postgresql-tile](http://www.dingotiles.com/dingo-postgresql/images/dingo-postgresql-tile.png)

Important links:

* [Support & Discussions](https://slack.dingotiles.com)
* [Licensing](#licensing)
* [Installation](#installation)
* [User documentation](http://www.dingotiles.com/dingo-postgresql/usage-provision.html), under "User" sidebar
* [Disaster recovery](http://www.dingotiles.com/dingo-postgresql/disaster-recovery.html)
* [BOSH release source](https://github.com/dingotiles/dingo-postgresql-release)
* [BOSH release releases](https://github.com/dingotiles/dingo-postgresql-release/releases)
* [BOSH release pipeline](https://ci.vsphere.starkandwayne.com/pipelines/dingo-postgresql-release)

Internal developer docs:

* [docker image tutorial](images/README.md) - learn the behavior of the Dingo PostgreSQL docker images without the overarching orchestration, how clusters are formed, how backups are configured, etc.
* [etcd schema](https://github.com/dingotiles/dingo-postgresql-broker/blob/master/docs/etcd_schema.md) - how/where/why data is stored in etcd

## Introduction

Users of Cloud Foundry expect that hard things are easy to do. For the first time, Dingo PostgreSQL makes it easy for any user of Cloud Foundry to provision an advanced, dynamically configuring cluster of PostgreSQL that provides high availablity across multiple availability zones.

Each cluster has an independent continuous backup which allows for [service instance disaster recovery for user disasters](http://www.dingotiles.com/dingo-postgresql/recover-user-deleted-service.html); and [entire platform disaster recovery](http://www.dingotiles.com/dingo-postgresql/disaster-recovery.html) for the worst disasters.

Deployments of Dingo PostgreSQL can be to any infrastructure supported by a BOSH CPI, such as vSphere, AWS, OpenStack, Google Compute, and Azure. Ideally, it would be deployed into the same infrastructure as the Cloud Foundry it will be connected to.

Backups can be stored and restored from numerous object stores, such as Amazon S3 or matching API, Microsoft Azure, and OpenStack Swift.

Dingo PostgreSQL offers a Cloud Foundry-compatible service broker [[API](http://docs.cloudfoundry.org/services/api.html)] to make it easy for Cloud Foundry operators to register Dingo PostgreSQL, and for Cloud Foundry users to use the service via the common `cf create-service` command set.

## Architecture

This BOSH release deploys a cluster of cells that can run high-availability clustered PostgreSQL. It includes a front-facing routing mesh to route connections the master/solo PostgreSQL node in each cluster.

Many PostgreSQL servers can be run on each cell/server. The solution uses Docker images for package PostgreSQL, and Docker engine to run PostgreSQL in isolated Linux containers.

Clustering between multiple nodes each PostgreSQL cluster is automatically coordinated by https://github.com/zalando/patroni, using etcd backend as a high-availability data store.

If a cell/server is lost, then replicas on other cells are promoted to be the master of each cluster, and the front facing router automatically starts directly traffic to the new master.

Refer to the [LEARNING_PATRONI](./LEARNING_PATRONI.md) guide for more information patroni.

## Licensing

The BOSH release is the basis for the Pivotal Network tile [Dingo PostgreSQL](http://www.dingotiles.com/dingo-postgresql/) and uses the same licensing system for commercial customers. As the licensing system applies to both this OSS BOSH release and the Pivotal tile, we are distributing all product features, support tooling, and documentation in both distributions.

![dingo-postgresql-tile](http://www.dingotiles.com/dingo-postgresql/images/dingo-postgresql-tile.png)

Both the OSS BOSH release and the Pivotal tile are free to trial for 10 service instances (one service instance is a cluster of PostgreSQL created by `cf create-service` command). Commercial license purchases can be purchased in service instance batches of 25. Please [chat with us on Slack](https://slack.dingotiles.com) to help getting started, discuss support & licensing, and to discuss future product direction.

## Installation

This section documents how to install/deploy Dingo PostgreSQL to BOSH.

*NOTE: for instructions for installing the tile, see http://www.dingotiles.com/dingo-postgresql/installation.html*

### Dependencies

Deploying the OSS BOSH release requires:

-	BOSH for target infrastructure, or bosh-lite
- `bosh` CLI to upload & deploy
-	`spruce` CLI to merge YAML files, from http://spruce.cf/
- `jq` & `curl` for the upload command & admin support scripts
- Log management system, such as hosted service like [Papertrail](papertrailapp.com) or on-prem system like ELK (https://www.elastic.co/products or http://logsearch.io/)
- Object storage service for backups, such as Amazon S3; with API credentials

## Upload required BOSH releases

This BOSH release is designed and tested to work with specific versions of 3rd party BOSH releases. The CI pipeline publishes final releases to Github that include the specific dependencies that have been tested to work.

To upload the latest release:

```
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/latest" | jq -r ".assets[].browser_download_url"  | grep tgz | xargs -L1 bosh upload release --skip-if-exists
```

Your BOSH will directly download and install the BOSH releases. They will not be downloaded to your local computer.

To upload a specific release, see https://github.com/dingotiles/dingo-postgresql-release/releases for specific upload instructions.

For example, if you are installing version `0.5.7`, then the following command will upload the specific releases that work together:

```
version=0.5.7
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/tags/v${version}" | jq -r ".assets[].browser_download_url"  | grep tgz | xargs -L1 bosh upload release --skip-if-exists
```

### Deployment

Upload some dependent BOSH releases to your BOSH:

```
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/etcd-release
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/route-registrar-boshrelease
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/simple-remote-syslog-boshrelease
```

Get the necessary submodules:

```
git submodule update --init --recursive --force
```

To use your own etcd cluster:

```
./templates/make_manifest warden upstream templates/services-cluster.yml tmp/etcd.yml
```

To deploy a simple one-node etcd cluster for demonstration purposes:

```
./templates/make_manifest warden upstream templates/services-cluster.yml templates/jobs-etcd.yml
```

Upload a Dingo PostgreSQL Release and deploy:

```
bosh create release --force && bosh upload release
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
