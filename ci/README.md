Pipeline to build images
========================

Update pipeline
---------------

From root of project:

```
fly -t vsphere sp -p $(basename $(pwd)) -c ci/pipeline.yml -l ci/credentials.yml
```

If you are missing some secret credentials for `ci/credentials.yml`, currently you'll need to ask a member of the dev team or look them up from the pipeline:

```
fly -t vsphere gp -p $(basename $(pwd))
```
