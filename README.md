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
* [How do I configure backups? Why is it mandatory?](#streaming-backups)
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
- 2 (two) Amazon S3 buckets with AWS API credentials (see [backups](#backups) section for information)
- `bosh` CLI to upload & deploy
-	`spruce` CLI to merge YAML files, from http://spruce.cf/
- `jq` & `curl` for the upload command & admin support scripts
- Log management system, such as hosted service like [Papertrail](papertrailapp.com) or on-prem system like ELK (https://www.elastic.co/products or http://logsearch.io/)

### Upload required BOSH releases

This BOSH release is designed and tested to work with specific versions of 3rd party BOSH releases. The CI pipeline publishes final releases to Github that include the specific dependencies that have been tested to work.

To upload the latest release:

```
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/latest" | jq -r ".assets[].browser_download_url"  | grep tgz | xargs -L1 bosh upload release --skip-if-exists
```

Your BOSH will directly download and install the BOSH releases. They will not be downloaded to your local computer.

To upload a specific release, see https://github.com/dingotiles/dingo-postgresql-release/releases for specific upload instructions.

For example, to upload the latest release and its associated dependency releases, then the following command will upload the specific releases that work together:

```
curl -s "https://api.github.com/repos/dingotiles/dingo-postgresql-release/releases/latest" | jq -r ".assets[].browser_download_url"  | grep tgz | xargs -L1 bosh upload release --skip-if-exists
```

### Deployment to bosh-lite

This section focuses on deploying Dingo PostgreSQL to bosh-lite (either running locally or remotely):

Get the BOSH release repository that contains the `spruce` templates we will use to build the BOSH deployment manifest:

```
git clone https://github.com/dingotiles/dingo-postgresql-release.git
cd dingo-postgresql-release
git submodule update --init
```

Next, create a template containing your Amazon S3 buckets and AWS API credentials, `tmp/backups.yml`:

```yaml
---
meta:
  backups:
    aws_access_key: KEY
    aws_secret_key: SECRET
    backups_bucket: our-dingo-postgresql-database-backups
    clusterdata_bucket: our-dingo-postgresql-clusterdata-backups
    region: ap-southeast-1
```

These buckets need to already exist. We do not want you to provide admin-level object store credentials that are capable of creating/destroyin buckets, so instead you will need to pre-create the buckets and wire up permissions for credentials to read/write to the buckets before usage.

To deploy the service and test that provisioning, updates, backups and recovery is working correctly:

```
./templates/make_manifest warden upstream \
  templates/services-cluster-backup-s3.yml templates/jobs-etcd.yml tmp/backups.yml
bosh deploy
bosh run errand sanity-test
```

The `sanity-test` errand is especially important for initial deployments - it will verify that your object storage credentials are valid, that the two buckets exist and are in the region/endpoint that you specified. It will also create/update/delete/recover some Dingo PostgreSQL clusters to confirm everything is working as expected. Fewer surprises later on!

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
./templates/make_manifest warden upstream \
  templates/services-cluster-backup-s3.yml templates/jobs-etcd.yml tmp/backups.yml \
  tmp/syslog.yml
bosh deploy
```

### Streaming backups

A database without a disaster recovery playbook (backup and restore) is a cache. One of Dingo PostgreSQL important features is that it is easy for an operator to enable streaming backups for every service instance. We do not support/test/encourage running Dingo PostgreSQL without backups configured.

We strongly recommend running the `sanity-test` errand immediately after each deployment of Dingo PostgreSQL - initial deployment, upgrades, configuration changes, etc. It includes tests that the backup & recovery systems are currently working.

Dingo PostgreSQL service instances are pairs of PostgreSQL servers, running in Docker containers on separate host machines, that continuously replica leader changes to replicas, and to a remote object store.

Dingo PostgreSQL provides administrator errand `disaster-recovery` to recreate every service instance from its continuous archives.

Dingo PostgreSQL provides users with `cf create-service ... -c '{"clone-from":"NAME"}'` to recreate a lost database or clone an existing database into a new service instance.

All this supported by the continuous archives.

Each PostgreSQL master container can continuously stream its write-ahead logs (WAL) to Amazon S3. These can later be used to restore clusters (see [Disaster Recovery](#disaster-recovery) section below), and may also internally used to create new replica nodes.

In future, Dingo PostgreSQL can support alternate object store/backup storage systems. Please let us know of your interests. Fundamentally, support for alternates is driven by the [wal-e](https://github.com/wal-e/wal-e), [boto](https://github.com/boto/boto) and [fog](https://github.com/fog/fog) OSS projects; and us being able to perform CI upon the target systems.

As above, you need two separate Amazon S3 buckets:

- one to store the streaming backups from every Dingo PostgreSQL service cluster (`meta.backups.backups_bucket` below), and
- one to backup the cluster data (routing, passwords, cluster sizing) for the event of a disaster recovery.

**Why two buckets?**  You use two different buckets to isolate the storage of all database admin credentials from the same location where all the database backups are stored.

In the installation example above, you provided a single set of AWS credentials to access both buckets. **In production** we recommend two sets of AWS credentials - one per AWS user, each with access only to one bucket.

## Disaster recovery

The instructions and tutorials for disaster recovery (for user's individual databases or for the entire platform) are available at:

* [Introduction to Disaster Recovery](http://www.dingotiles.com/dingo-postgresql/disaster-recovery.html)
* [Recover a user’s deleted service instance](http://www.dingotiles.com/dingo-postgresql/recover-user-deleted-service.html)
* [Recover from complete disasters](http://www.dingotiles.com/dingo-postgresql/recover-from-complete-disaster.html)
