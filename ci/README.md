Pipeline to build images
========================

Update pipeline
---------------

```
fly -t snw c postgresql-docker-images -c ci/pipeline.yml --vf ci/credentials.yml
```
