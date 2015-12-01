Pipeline to build images
========================

Update pipeline
---------------

From root of project:

```
fly -t snw set-pipeline -p patroni-boshrelease -c ci/pipeline.yml -l ci/credentials.yml
```
