# Failure Scenarios

```
alias dc=docker-compose
```

## Etcd down
| failure | recovery | what happens? |
|---|---|---|
| `dc up -d john; dc stop etcd; dc rm -f` | `dc up -d etcd` | registrator stops publishing ports and john demotes to read only -> everything back to normal |

## 1 Node, master goes down
| failure | recovery |
|---|---|---|
| `dc up -d john; tutorial/pgbench.sh; dc stop john; dc rm -f` | `dc start -d john` |

| test | condition | wal-e | result | reason |
| --- | --- | --- | --- | --- |
| `tests/master_recovers_quickly.sh` | master is brought back up before leader key expires in etcd | doesn't matter | back up proceeds as expected. john becomes leader | |
| `tests/master_recovers_slowly.sh` | master is brought back up after leader key expires in etcd | no | `INFO: waiting for leader to bootstrap` | Expected behaviour loop around step `Leader owns key?` in [this](https://github.com/zalando/patroni/blob/master/postgres-ha.pdf) diagram |
| `tests/master_recovers_slowly.sh` | master is brought back up after leader key expires in etcd | yes | john restores in read-only and doesn't become leader; wal-e gets stuck in endless restore loop | |
