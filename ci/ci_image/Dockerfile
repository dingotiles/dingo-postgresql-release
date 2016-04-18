FROM concourse/concourse-ci
# https://github.com/concourse/concourse/blob/master/ci/dockerfiles/concourse-ci/Dockerfile

RUN apt-get update && apt-get install file curl wget bzr jq -y && \
    apt-get clean

ADD https://github.com/geofffranks/spruce/releases/download/v1.1.2/spruce-linux-amd64 /usr/bin/spruce
RUN chmod 755 /usr/bin/spruce

RUN gem install rake --no-ri --no-rdoc && \
    apt-get update && apt-get install tree -y && apt-get clean

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go1.6.1.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1

# Set environment variables.
ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
