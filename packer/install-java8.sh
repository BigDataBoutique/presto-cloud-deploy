#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

# Add the Java 8 repository.
log "Adding repository and updating packages list"
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update -y -qq

# Set the "don't bother us" option to install.
echo debconf shared/accepted-oracle-license-v1-1 select true | \
sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | \
sudo debconf-set-selections

# Install Java 8.
log "Executing install"
sudo apt-get install -y -qq oracle-java8-installer oracle-java8-set-default

export JAVA_HOME=$(jrunscript -e 'java.lang.System.out.println(java.lang.System.getProperty("java.home"));')
/usr/bin/printf "
JAVA_HOME=${JAVA_HOME}" >> /etc/environment