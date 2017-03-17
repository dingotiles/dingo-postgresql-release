# Dingo PostgreSQL Deployment

This folder includes a base deployment manifest for any BOSH that has a cloud-config installed. These instructions assume the use of the new `bosh2` CLI.

```
BOSH_ENVIRONMENT=name-of-bosh-with-cloud-config
bosh2 -d dingo-postgresql deploy deployment/dingo-postgresql.yml
```
