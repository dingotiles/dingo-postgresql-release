
### disaster-recovery errand supports buddy-broker derived services/plans

A service/plan registered with https://github.com/cloudfoundry-community/buddy-broker will have GUIDs that
are prefixed with the root service ID. So we now search thru all
pages of /v2/services, looking for multiple services that
have the GUID of or prefixed by the provided root service ID.

### dpg support tool

Previously only available in `bin/dpg` within the BOSH release,
this support tool is now installable as a BOSH job template `dpg-cli`.
The spruce templates automatically add it to `router` job.
It pre-configures `dpg` with cf, etcd, and service broker credentials;
and makes `dpg` immediately runnable as `root` user.

To add `dpg-cli` to `router` job (or any other), add to the job and provide properties:

```yaml
- name: router
  instances: 1
  templates:
    - {name: remote-syslog, release: simple-remote-syslog}
    - {name: broker, release: dingo-postgresql}
    - {name: router, release: dingo-postgresql}
    - {name: dpg-cli, release: dingo-postgresql}
  properties:
    servicebroker:
      machines: [127.0.0.1]
      port: 8889 # internally binding
      username: starkandwayne
      password: starkandwayne
    cf:
      api_url: ...
      username: ...
      password: ...
      skip_ssl_validation: false
    etcd:
      machines: [...]
```

Then, after `bosh ssh router/0`, change to root user and try `dpg`:

```
bosh ssh router/0
sudo su -
dpg ls
```

To see help, run `dpg` without arguments.

Example commands to test drive the support tool:

```
dpg
dpg target
dpg ls
```

The first column are the Cloud Foundry service instance IDs, referenced as `INSTANCE_ID` in the `dpg` help above.

```
dgp status INSTANCE_ID
```

To create or delete service instances without Cloud Foundry API/CLI:

```
dpg create my-first-cluster
dpg ls
dpg raw /service/my-first-cluster
dpg raw /service/my-first-cluster/members
```

Once the cluster is up and running:

```
dpg superuser-psql my-first-cluster
```

This will provide a `psql` interactive console:

```
psql (9.4.5, server 9.5.3)
WARNING: psql major version 9.4, server major version 9.5.
         Some psql features might not work.
Type "help" for help.

postgres=#
```

Continuing with example commands:

```
dpg wale-backup-list my-first-cluster
dpg delete my-first-cluster
```

NOTE: `my-first-cluster` will be a long UUID/GUID for values provided by Cloud Foundry; and a value prefixed by `T-` when created by the `sanity-test` errand (which can be deleted if you see them).
