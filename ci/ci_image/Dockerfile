FROM concourse/concourse-ci
# https://github.com/concourse/concourse/blob/master/ci/dockerfiles/concourse-ci/Dockerfile

RUN apt-get update && \
    apt-get install file curl wget bzr jq postgresql postgresql-contrib -y && \
    apt-get clean

ADD https://github.com/geofffranks/spruce/releases/download/v1.1.2/spruce-linux-amd64 /usr/bin/spruce
RUN chmod 755 /usr/bin/spruce

ADD https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.17.0 /tmp/cf.tgz
RUN tar xzf /tmp/cf.tgz -C /usr/bin && rm /tmp/cf.tgz

RUN gem install rake -v 11.0.1 --no-ri --no-rdoc && \
    gem install license_finder --no-ri --no-rdoc && \
    apt-get update && apt-get install tree -y && apt-get clean

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1

# Set environment variables.
ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
