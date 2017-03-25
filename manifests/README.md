# Dingo PostgreSQL Deployment

This folder includes a base deployment manifest for any BOSH that has a cloud-config installed. These instructions assume the use of the new `bosh2` CLI.

From the root folder:

```
export BOSH_ENVIRONMENT=${BOSH_ENVIRONMENT:?required}
export BOSH_DEPLOYMENT=dingo-postgresql

bosh2 int manifests/dingo-postgresql.yml --var-errs --vars-store=tmp/creds.yml
bosh2 deploy manifests/dingo-postgresql.yml --vars-store=tmp/creds.yml
```

This will fail; but will show you all the required input variables/parameters.

Create a YAML file containing all the required input variables, say `tmp/vars.yml`:

```
backups_clusterdata_aws_access_key_id: ...
backups_database_storage_bucket_name: ...
...
```

Some variables have been automatically generated into `creds.yml`:

```
cf_containers_broker_password: 89vc26d4rrj4vimrookt
dingo_broker_password: r6sypnm6wp757qichd3o
...
```

## Store & retrieve creds from Vault

You might want some input variables to be hidden inside Vault, such as AWS access credentials.

```
safe set secret/dingo-postgresql/demo/aws/clusterdata aws_access_key_id=... aws_secret_access_key=...
safe set secret/dingo-postgresql/demo/aws/database_storage aws_access_key_id=... aws_secret_access_key=...
```

You can fetch these into an input YAML file via `spruce merge`:

```
VAULT_PREFIX=secret/dingo-postgresql/demo spruce merge manifests/spruce-vault-secrets.yml
```

This allows you to pass these secrets directly to the `bosh2` command with the `-l` flag:

```
export VAULT_PREFIX=secret/dingo-postgresql/demo
bosh2 int manifests/dingo-postgresql.yml \
  --vars-store=tmp/creds.yml \
  -l tmp/vars.yml \
  -l <(spruce merge manifests/spruce-vault-secrets.yml)
bosh2 deploy manifests/dingo-postgresql.yml \
  --vars-store=tmp/creds.yml \
  -l tmp/vars.yml \
  -l <(spruce merge manifests/spruce-vault-secrets.yml)
```
