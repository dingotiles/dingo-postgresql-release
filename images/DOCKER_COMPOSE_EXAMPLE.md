# Exploring with Docker Compose

The docker images in this folder include `delmo` tests, which leverage `docker-compose` to bring up a cluster including a test script container.

The `docker-compose.yml` can be used for local experimentation. In this doc, I'm using "Docker for Mac".

First, get the laptop's IP:

```
ifconfig
```

And set the `DOCKER_HOST_IP` env var:

```
export DOCKER_HOST_IP=192.168.0.138
```

To download docker images, and to create the test image, run:

```
docker-compose -f docker-compose.yml up
```

This may take some time on the first run.

In another window, you can poll each Patroni's REST API for its status (`watch -n1` will poll each second):

```
watch -n1 "curl -s ${DOCKER_HOST_IP}:8001 | jq .; echo; curl -s ${DOCKER_HOST_IP}:8002 | jq ."
```

To shut down the docker-compose cluster, press Ctrl-C.

I've found that I need to clean up the patroni/etcd containers and their volumes prior to restarting the cluster:

```
docker rm images_etcd_1; docker rm patroni1; docker rm patroni2; docker volume ls | grep local | awk '{print $2}' | xargs -L1 docker volume rm
```

To combine the cleanup and restart command:

```
docker rm images_etcd_1; docker rm patroni1; docker rm patroni2; docker volume ls | grep local | awk '{print $2}' | xargs -L1 docker volume rm; docker-compose -f docker-compose.yml up
```

Running `docker-compose up` and the `watch` poller in parallel windows will look like:

![docker](https://cl.ly/1e2r28440d2P/download/Image%202016-07-11%20at%2011.04.13%20AM.png)
