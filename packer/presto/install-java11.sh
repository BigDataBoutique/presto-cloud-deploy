#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

# Install Java 11.
log "Executing install"
sudo apt-get install default-jdk -y -qq

export JAVA_HOME=$(jrunscript -e 'java.lang.System.out.println(java.lang.System.getProperty("java.home"));')
/usr/bin/printf "
JAVA_HOME=${JAVA_HOME}" >> /etc/environment
