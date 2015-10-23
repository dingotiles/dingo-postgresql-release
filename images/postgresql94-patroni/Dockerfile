FROM cfcommunity/postgresql-base:9.4
MAINTAINER Dr Nic Williams

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -y && \
    apt-get install python python-psycopg2 python-yaml \
    python-requests python-boto python-dnspython python-kazoo python-pip \
    daemontools -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install python-etcd

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
