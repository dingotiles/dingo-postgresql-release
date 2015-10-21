#!/bin/bash

export PG_VERSION=9.4

export PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH

echo "Starting Patroni..."
python /patroni/patroni.py /patroni/postgres.yml
