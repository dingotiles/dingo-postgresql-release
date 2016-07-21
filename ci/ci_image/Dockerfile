FROM ubuntu:15.10

RUN apt-get update && \
    apt-get -y install git zip unzip \
        libxml2-dev libxslt-dev libcurl4-openssl-dev \
        build-essential zlib1g-dev libssl-dev libreadline6-dev libyaml-dev \
    && apt-get install file curl wget bzr jq postgresql postgresql-contrib -y \
    && apt-get install tree \
    && apt-get clean

# install ruby
RUN cd \
      && wget http://ftp.ruby-lang.org/pub/ruby/2.2/ruby-2.2.5.tar.gz \
      && tar -xzvf ruby-2.2.5.tar.gz \
      && cd ruby-2.2.5/ \
      && ./configure \
      && make \
      && make install \
      && ruby -v

# install required gems
RUN gem install bundler --no-rdoc --no-ri \
      && gem install bosh_cli -v 1.3177.0 --no-rdoc --no-ri \
      && gem install license_finder --no-ri --no-rdoc

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1

# Set environment variables.
ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH

ADD https://github.com/geofffranks/spruce/releases/download/v1.1.2/spruce-linux-amd64 /usr/bin/spruce
RUN chmod 755 /usr/bin/spruce

ADD https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.17.0 /tmp/cf.tgz
RUN tar xzf /tmp/cf.tgz -C /usr/bin && rm /tmp/cf.tgz
