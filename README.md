Patroni for Cloud Foundry
=========================

Background
----------

### cf-containers-broker job

The `cf-containers-broker` job is a fork of https://github.com/cf-platform-eng/cf-containers-broker. At the time of forking, the project did not support any mechanism for advertising the `host:port` for each container port into the container itself. https://github.com/cf-platform-eng/cf-containers-broker/pull/33 was proposed; but not yet merged; nor an alternate implementation available yet.

### docker job

This BOSH release includes a `docker` job, even though one is available in https://github.com/cf-platform-eng/docker-boshrelease. Unfortunately, if you fork `cf-containers-broker` job then you need to recreate all the dependency packages with different names that do not clash with `docker-boshrelease` packages. Instead of this path, I chose to `bosh-gen extract-pkg` the `docker` job from the docker-boshrelease. The job & packages will be maintained to be equivalent.
