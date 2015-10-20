FROM cfcommunity/postgresql-base:9.4
MAINTAINER Dr Nic Williams

# Add scripts
ADD scripts /scripts
RUN chmod +x /scripts/*.sh
RUN touch /.firstrun

# Command to run
ENTRYPOINT ["/scripts/run.sh"]
CMD [""]

# Expose listen port
EXPOSE 5432

# Expose our data directory
VOLUME ["/data"]

# jq used by backup.sh & restore.sh
ADD http://stedolan.github.io/jq/download/linux64/jq /usr/bin/
RUN chmod 775 /usr/bin/jq
