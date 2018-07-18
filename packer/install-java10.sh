#!/usr/bin/env bash
set -e

add-apt-repository ppa:linuxuprising/java
apt-get update -y -qq

echo oracle-java10-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections

apt-get install -y -qq oracle-java10-installer oracle-java10-set-default