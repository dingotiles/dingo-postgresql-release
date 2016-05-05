[This doc was extracted from README and has not yet been rewritten as a dedicated doc]

### ETCD cluster

This system assumes you have an etcd cluster running.

Why etcd? It is the common denominator between registrator, patroni and confd. For example, to support consul we would first need to add consul support to patroni. There are also shell scripts now that assume etcd; so they'd need updating or replacing with executable that support different backends.

The templates include an easy way to run an etcd node, if you don't already have an etcd cluster, using [cloudfoundry-incubator/etcd-release](https://github.com/cloudfoundry-incubator/etcd-release). See "Deployment" section for instructions.

If you do already have an etcd cluster then create a spruce stub file with your etcd cluster information, say `tmp/etcd.yml`:

```yaml
---
meta:
  etcd:
    host: 10.244.4.2
  registrator:
    backend_uri: (( concat "etcd://" meta.etcd.host ":4001" ))
```
