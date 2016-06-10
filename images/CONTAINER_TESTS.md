# Testing dingo-postgresql docker containers

We are using [delmo](https://github.com/bodymindarts/delmo) to test the automatic failover and backup/recovery features of the docker containers used in dingo-postgresql.

To run the tests you need the following docker-tools pre-installed
- docker-compose
- docker-machine

Download the latest [delmo-release](https://github.com/bodymindarts/delmo/releases) and run the tests via:
```bash
delmo # if you are in the images dir, otherwise:
delmo -f images/delmo.yml
```

To run the tests on a remote docker-machine
```bash
delmo -f images/delmo.yml -m <remote-machine-name>
```

If you don't want to build the images from scratch but just use the latest ones from the upstream docker-hub repo use:
```bash
delmo -f images/delmo.yml --only-build-task
```
