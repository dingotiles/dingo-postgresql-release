FROM frodenas/ubuntu
MAINTAINER Dr Nic Williams

ENV PG_VERSION=9.5 \
    POSTGIS_VERSION=2.2
RUN DEBIAN_FRONTEND=noninteractive \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main ${PG_VERSION}" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -y && \
    apt-get install python python-dev python-pip lzop pv \
    daemontools libpq-dev \
    postgresql-${PG_VERSION} \
    postgresql-${PG_VERSION}-postgis-${POSTGIS_VERSION} \
    postgresql-${PG_VERSION}-pgrouting \
    jq -y && \
    service postgresql stop && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install pip --upgrade
RUN pip install wal-e awscli --upgrade

ENV PATH /usr/lib/postgresql/${PG_VERSION}/bin:$PATH
