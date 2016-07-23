FROM frodenas/ubuntu
MAINTAINER Dr Nic Williams

ENV PG_VERSION=9.5 \
    POSTGIS_VERSION=2.2 \
    JQ_VERSION=1.5

RUN DEBIAN_FRONTEND=noninteractive \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main ${PG_VERSION}" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update -y \
    && apt-get install -y python python-dev python-pip lzop pv \
    dumb-init \
    daemontools libpq-dev \
    postgresql-${PG_VERSION} \
    postgresql-${PG_VERSION}-postgis-${POSTGIS_VERSION} \
    postgresql-${PG_VERSION}-pgrouting \
    && service postgresql stop \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install pip --upgrade \
      && pip install wal-e awscli --upgrade

RUN wget https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 \
      && chmod +x jq-linux64 \
      && mv jq-linux64 /usr/local/bin/jq \
      && jq --version

ENV PATH /usr/lib/postgresql/${PG_VERSION}/bin:$PATH
