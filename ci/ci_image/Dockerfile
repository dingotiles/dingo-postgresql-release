FROM concourse/concourse-ci
# https://github.com/concourse/concourse/blob/master/ci/dockerfiles/concourse-ci/Dockerfile

RUN apt-get update && apt-get install file -y && \
    apt-get clean

ADD https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 /usr/bin/jq
RUN chmod 775 /usr/bin/jq

ADD https://github.com/geofffranks/spruce/releases/download/v1.1.2/spruce-linux-amd64 /usr/bin/spruce
RUN chmod 755 /usr/bin/spruce

RUN gem install rake --no-ri --no-rdoc && \
    apt-get update && apt-get install tree -y && apt-get clean
