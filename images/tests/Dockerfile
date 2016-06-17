FROM alpine

# psql
RUN apk add --update bash jq curl postgresql py-pip python-dev alpine-sdk linux-headers \
      && rm -rf /var/cache/apk/*
RUN pip install wal-e awscli envdir --upgrade

# etcdctl
RUN curl -L https://github.com/coreos/etcd/releases/download/v2.3.4/etcd-v2.3.4-linux-amd64.tar.gz -o /tmp/etcd-v2.3.4-linux-amd64.tar.gz \
      && tar xzvf /tmp/etcd-v2.3.4-linux-amd64.tar.gz -C /tmp \
      && mv /tmp/etcd-v2.3.4-linux-amd64/etcdctl /usr/local/bin \
      && rm -rf /tmp/etcd*

ADD ./scripts/  /scripts

CMD /bin/true
