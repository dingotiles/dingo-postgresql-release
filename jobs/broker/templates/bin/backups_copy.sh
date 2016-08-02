#!/bin/bash

set -e

json=$(cat -)
from_uri=$(echo $json | jq -r ".from_uri")
to_uri=$(echo $json | jq -r ".to_uri")

<% if_p("backups.database_storage.aws_access_key_id", "backups.database_storage.aws_secret_access_key", "backups.database_storage.region") do |aws_access_key_id, aws_secret_access_key, region| %>
# setup awscli configuration
mkdir -p ~/.aws
chmod 700 ~/.aws

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = <%= aws_access_key_id %>
aws_secret_access_key = <%= aws_secret_access_key %>
EOF
chmod 600 ~/.aws/credentials

cat > ~/.aws/config <<EOF
[default]
region = <%= region %>
EOF
chmod 600 ~/.aws/config

export LD_LIBRARY_PATH=/var/vcap/packages/python/lib
export PATH=$PATH:/var/vcap/packages/python/bin:/var/vcap/packages/awscli/bin
aws s3 cp $from_uri $to_uri --recursive

<% end.else do %>
echo "No configuration provided to copy Amazon S3 folders"
exit 1
<% end %>
