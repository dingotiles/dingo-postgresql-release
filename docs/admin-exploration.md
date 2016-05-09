[this page contains some old sections from README which might provide some help]

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
