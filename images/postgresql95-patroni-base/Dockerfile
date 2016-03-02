FROM cfcommunity/postgresql-base:9.5
MAINTAINER Dr Nic Williams

ENV PG_VERSION=9.5
ENV POSTGIS_VERSION=2.2
RUN DEBIAN_FRONTEND=noninteractive \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main ${PG_VERSION}" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -y && \
    apt-get install python python-dev python-psycopg2 python-yaml \
    python-requests python-boto python-dnspython python-kazoo python-pip \
    gdb strace libxml2-dev libxslt-dev libffi-dev lzop pv \
    libpq-dev \
    daemontools \
    postgresql-${PG_VERSION} \
    postgresql-${PG_VERSION}-postgis-${POSTGIS_VERSION} \
    postgresql-${PG_VERSION}-pgrouting && \
    jq -y && \
    service postgresql stop && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install pip --upgrade
# WAL-e requests a relatively new version of requests, install other modules via pip as well
RUN pip install python-etcd requests six wal-e psycopg2 dnspython kazoo --upgrade

ENV PATH /usr/lib/postgresql/${PG_VERSION}/bin:$PATH
