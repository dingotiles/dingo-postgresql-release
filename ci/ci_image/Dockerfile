FROM concourse/concourse-ci
# https://github.com/concourse/concourse/blob/master/ci/dockerfiles/concourse-ci/Dockerfile

RUN apt-get update && apt-get install file -y && \
    apt-get clean

ADD https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 /usr/bin/jq
RUN chmod 775 /usr/bin/jq

ADD https://github.com/geofffranks/spruce/releases/download/v1.1.2/spruce_1.1.2_linux_amd64.tar.gz /tmp/
RUN cd /tmp/ && tar xfz spruce*.tar.gz && mv spruce_1.1.2_linux_amd64/spruce /usr/bin/spruce && chmod 755 /usr/bin/spruce

RUN gem install rake --no-ri --no-rdoc
