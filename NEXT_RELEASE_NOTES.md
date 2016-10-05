
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
dpg create test
dpg delete test
```
