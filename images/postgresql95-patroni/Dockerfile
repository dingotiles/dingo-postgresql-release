FROM dingotiles/dingo-postgresql95-base:latest
MAINTAINER Dr Nic Williams

# Expose listen port
EXPOSE 5432

# Expose patroni API port
EXPOSE 8008

# Expose our data directory
VOLUME ["/data"]

ADD patroni/patroni.py /patroni.py
ADD patroni/patroni /patroni
ADD patroni/requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

# Add scripts
ADD scripts /scripts
RUN chmod +x /scripts/*.sh /scripts/postgres/*.sh

# Command to run
CMD ["/scripts/run.sh"]
