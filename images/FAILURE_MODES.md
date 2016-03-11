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

| condition | result |
| --- | --- |
| master is brought back up before leader key expires in etcd | back up proceeds as expected. john becomes leader |
