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
* [Admin features of service broker](https://github.com/dingotiles/dingo-postgresql-broker#recreate-service-api)
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

Please [chat with us on Slack](https://slack.dingotiles.com) to help getting started, discuss support & licensing, and to discuss future product direction.

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

### Upload required BOSH releases

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

### Deployment to bosh-lite

This section focuses on deploying Dingo PostgreSQL to bosh-lite (either running locally or remotely):

Get the BOSH release repository that contains the `spruce` templates we will use to build the BOSH deployment manifest:

```
git clone https://github.com/dingotiles/dingo-postgresql-release.git
cd dingo-postgresql-release
git submodule update --init
```

As the first step, to deploy the service without backups nor syslogs:

```
./templates/make_manifest warden upstream templates/services-cluster.yml templates/jobs-etcd.yml
bosh deploy
```

To register your new Dingo PostgreSQL service broker with your bosh-lite Cloud Foundry:

```
cf create-service-broker dingo-postgresql starkandwayne starkandwayne http://10.244.21.2:8889
```

To enable the service to all organizations:

```
cf enable-service-access dingo-postgresql
```

To view the service offering, and to create your first Dingo PostgreSQL service cluster:

```
cf marketplace
cf marketplace -s dingo-postgresql
cf create-service dingo-postgresql cluster-dev pg-dev
```

To learn more about provisioning, binding and using the Dingo PostgreSQL cluster visit the documentation http://www.dingotiles.com/dingo-postgresql/usage-provision.html

The name `cluster-dev` service plan reflects that currently the service instance has no streaming backups configured. See section [Streaming backups to Amazon S3](#streaming-backups-to-amazon-s3) below to switch to a service plan that offers streaming backups to every Dingo PostgreSQL cluster automatically.

### Remote syslog

To aide with understanding and debugging it is very important to see all logs from system components of Dingo PostgreSQL, and from the running Docker containers for each service instance.

Dingo PostgreSQL can stream all component and container logs to a central syslog endpoint for viewing and discovery by administrators.

To ship logs to a remote syslog endpoint, create a YAML file like (in the example below it is at `tmp/syslog.yml`):

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

For example, for [papertrail](https://papertrailapp.com) you can get your host:port details from https://papertrailapp.com/systems/setup; or can register a new syslog endpoint at https://papertrailapp.com/systems/new.

Then append the file in your `make_manifest` command (from above) to build your BOSH deployment manifest.

```
./templates/make_manifest warden upstream templates/services-cluster.yml templates/jobs-etcd.yml \
  tmp/syslog.yml
bosh deploy
```

### Streaming backups to Amazon S3

A database without a disaster recovery playbook (backup and restore) is a cache. One of Dingo PostgreSQL important features is that it is easy for an operator to enable streaming backups for every service instance.

Each PostgreSQL master container can continuously stream its write-ahead logs (WAL) to Amazon S3. These can later be used to restore clusters (see [Disaster Recovery](#disaster-recovery) section below), and may also internally used to create new replica nodes.

You will need two separate Amazon S3 buckets - one to store the streaming backups from every Dingo PostgreSQL service cluster (`meta.backups.backups_bucket` below), and one to backup the cluster data (routing, passwords, cluster sizing) for the event of a disaster recovery.

Create a YAML file with configuration (`tmp/backups.yml` in example command below):

```yaml
---
meta:
  backups:
    aws_access_key: ACCESSKEY
    aws_secret_key: SECRETKEY
    backups_bucket: mycompany-dingo-postgresql-testflight-backups
    clusterdata_bucket: mycompany-dingo-postgresql-testflight-clusterdata-backups
    s3_endpoint: s3-ap-southeast-1.amazonaws.com
    region: ap-southeast-1
```

Re-run the `make_manifest` command from above but with the following changes:

* append this file
* replace `templates/services-cluster.yml` with `templates/services-cluster-backup-s3.yml` template

```
./templates/make_manifest warden upstream templates/jobs-etcd.yml \
  tmp/syslog.yml \
  templates/services-cluster-backup-s3.yml tmp/backups.yml
bosh deploy
```

Next:

* update broker with new service plan information (`cluster-dev` changes to `cluster`)

```
cf update-service-broker dingo-postgresql starkandwayne starkandwayne http://10.244.21.2:8889
```

* create new service instance

```
cf create-service dingo-postgresql cluster pg-prod
cf service pg-prod
```

* update pg-dev above to enable backups on existing cluster

```
cf update-service dingo-postgresql cluster pg-dev
cf service pg-prod
```

To learn and explore how this configuration data is passed down into the Docker containers that run Patroni and PostgreSQL, see [image tutorial](https://github.com/dingotiles/dingo-postgresql-release/tree/master/images#backuprestore-from-aws).

## Disaster recovery

The instructions and tutorials for disaster recovery (for user's individual databases or for the entire platform) are available at:

* [Introduction to Disaster Recovery](http://www.dingotiles.com/dingo-postgresql/disaster-recovery.html)
* [Recover a user’s deleted service instance](http://www.dingotiles.com/dingo-postgresql/recover-user-deleted-service.html)
* [Recover from complete disasters](http://www.dingotiles.com/dingo-postgresql/recover-from-complete-disaster.html)
