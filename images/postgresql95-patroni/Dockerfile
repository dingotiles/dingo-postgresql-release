FROM cfcommunity/postgresql-patroni-base:9.5
MAINTAINER Dr Nic Williams

# Command to run
ENTRYPOINT ["/scripts/run.sh"]
CMD [""]

# Expose listen port
EXPOSE 5432

# Expose our data directory
VOLUME ["/data"]

ADD patroni/patroni.py /patroni.py
ADD patroni/patroni /patroni
ADD patroni/requirements-py2.txt /requirements-py2.txt
RUN pip install -r /requirements-py2.txt

# Add scripts
ADD scripts /scripts
RUN chmod +x /scripts/*.sh /scripts/postgres/*.sh
