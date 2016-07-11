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

The following might combine these two steps nicely:

```
export DOCKER_HOST_IP=$(ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | head -n1 | awk '{print $2}')
echo $DOCKER_HOST_IP
```

To download docker images, and to create the test image, run:

```
docker-compose -f docker-compose.yml up
```

This may take some time on the first run.

In another window, you can poll each Patroni's REST API for its status (`watch -n1` will poll each second):

```
watch -n1 "curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/test-cluster/members | jq -r '.node.nodes[].key'; echo; curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/test-cluster/leader | jq -r .node.value; echo; curl -s ${DOCKER_HOST_IP}:8001 | jq .; echo; curl -s ${DOCKER_HOST_IP}:8002 | jq ."
```

To shut down the docker-compose cluster, press Ctrl-C.

I've found that I need to clean up the patroni/etcd containers and their volumes prior to restarting the cluster:

```
docker-compose -f docker-compose.yml rm -f -v
```

To combine the cleanup and restart command:

```
docker-compose -f docker-compose.yml rm -f -v; docker-compose -f docker-compose.yml up
```

Running `docker-compose up` and the `watch` poller in parallel windows will look like:

![docker](https://cl.ly/1e2r28440d2P/download/Image%202016-07-11%20at%2011.04.13%20AM.png)

In another window you can explore shutting down and restarting the leader/replica.

To look up and shutdown the leader:

```
leader=$(curl -s ${DOCKER_HOST_IP}:4001/v2/keys/service/test-cluster/leader | jq -r .node.value)
docker-compose -f docker-compose.yml stop $leader
docker-compose -f docker-compose.yml rm -f -v $leader
```

Eventually, the replica will failover to become leader.

Recreate old leader (variable `$leader` was set above):

```
docker-compose -f docker-compose.yml up -d $leader
```
