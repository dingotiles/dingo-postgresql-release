Patroni for Cloud Foundry
=========================

Background
----------

### registrator job

This is running a fork of gliderlabs/registrator https://github.com/drnic/registrator/tree/hostname-override that allows use to set the `-hostname` used in the registration. This means we can use BOSH VM information; rather than generic IaaS hostname info. This is especially good for bosh-lite vms which share the same common `hostname`.

Usage
-----

To directly target a Patroni/Docker node's broker and create a container:

```
id=1; broker=localhost; curl -v -X PUT http://containers:containers@${broker}/v2/service_instances/${id} -d '{"service_id": "0f5c1670-6dc3-11e5-bc08-6c4008a663f0", "plan_id": "1545e30e-6dc3-11e5-826a-6c4008a663f0", "organization_guid": "x", "space_guid": "x"}' -H "Content-Type: application/json"
```
