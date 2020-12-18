#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

sudo apt-get update
sudo apt-get install -y -qq openjdk-8-jdk openjdk-11-jdk default-jdk


sudo update-java-alternatives  --jre-headless --jre -s java-1.8.0-openjdk-amd64
export JAVA8_HOME=$(jrunscript -e 'java.lang.System.out.println(java.lang.System.getProperty("java.home"));')

sudo update-java-alternatives  --jre-headless --jre -s java-1.11.0-openjdk-amd64
export JAVA_HOME=$(jrunscript -e 'java.lang.System.out.println(java.lang.System.getProperty("java.home"));')

/usr/bin/printf "
JAVA8_HOME=${JAVA8_HOME}
JAVA_HOME=${JAVA_HOME}" >> /etc/environment