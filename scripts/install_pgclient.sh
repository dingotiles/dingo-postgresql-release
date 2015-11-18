#!/bin/bash

ubuntu_codename=$(lsb_release -c | awk '{print $2}')
echo "deb http://apt.postgresql.org/pub/repos/apt/ ${ubuntu_codename}-pgdg main" >/etc/apt/sources.list.d/pgdg.list 
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get install postgresql-client-9.4 postgresql-contrib-9.4 -y
