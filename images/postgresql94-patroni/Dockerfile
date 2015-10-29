FROM cfcommunity/postgresql-patroni-base:9.4
MAINTAINER Dr Nic Williams

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
