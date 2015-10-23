FROM cfcommunity/postgresql-base:9.4
MAINTAINER Dr Nic Williams

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -y && \
    apt-get install python python-psycopg2 python-yaml \
    python-requests python-boto python-dnspython python-kazoo python-pip \
    gdb strace libxml2-dev libxslt-dev libffi-dev lzop pv \
    daemontools -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install pip --upgrade
# WAL-e requests a relatively new version of requests, install other modules via pip as well
RUN pip install python-etcd requests six wal-e psycopg2 dnspython kazoo --upgrade

ENV PATH /usr/lib/postgresql/${PG_VERSION}/bin:$PATH

ADD patroni/patroni.py /patroni.py
ADD patroni/patroni /patroni

# Add scripts
ADD scripts /scripts
RUN chmod +x /scripts/*.sh

# Command to run
ENTRYPOINT ["/scripts/run.sh"]
CMD [""]

# Expose listen port
EXPOSE 5432

# Expose our data directory
VOLUME ["/data"]
