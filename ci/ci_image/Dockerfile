FROM ubuntu:15.10

RUN apt-get update && \
    apt-get -y install git zip unzip \
        libxml2-dev libxslt-dev libcurl4-openssl-dev \
        build-essential zlib1g-dev libssl-dev libreadline6-dev libyaml-dev \
    && apt-get install file curl wget bzr jq postgresql postgresql-contrib -y \
    && apt-get install tree \
    && apt-get clean

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1

# Set environment variables.
ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH

RUN go get -d github.com/cloudfoundry/bosh-cli && \
    cd $GOPATH/src/github.com/cloudfoundry/bosh-cli && \
    bin/build-linux-amd64 && \
    mkdir -p $GOPATH/bin && \
    ls -al out/ && \
    mv out/bosh $GOPATH/bin/bosh2

# RUN mkdir -p $GOPATH/src/github.com/cppforlife && \
#     cd $GOPATH/src/github.com/cppforlife && \
#     git clone https://github.com/cppforlife/bosh-lint && \
#     cd bosh-lint && \
#     bin/build && \
#     mv out/bosh-lint $GOPATH/bin

# install ruby
RUN cd \
      && wget http://ftp.ruby-lang.org/pub/ruby/2.3/ruby-2.3.3.tar.gz \
      && tar -xzvf ruby-2.3.3.tar.gz \
      && cd ruby-2.3.3/ \
      && ./configure \
      && make \
      && make install \
      && ruby -v

# install required gems
RUN gem install bundler --no-rdoc --no-ri \
      && gem install bosh_cli --no-rdoc --no-ri \
      && gem install license_finder --no-ri --no-rdoc

ADD https://github.com/geofffranks/spruce/releases/download/v1.8.13/spruce-linux-amd64 /usr/bin/spruce
RUN chmod 755 /usr/bin/spruce

ADD https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.25.0 /tmp/cf.tgz
RUN tar xzf /tmp/cf.tgz -C /usr/bin && rm /tmp/cf.tgz

ENV VAULT_VERSION 0.6.5
RUN wget -qO /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
      unzip -d /bin /tmp/vault.zip && rm /tmp/vault.zip && chmod 755 /bin/vault
