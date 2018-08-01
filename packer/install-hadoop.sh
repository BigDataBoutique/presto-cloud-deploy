#!/usr/bin/env bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export path_install="/usr/local/hadoop-${HADOOP_VERSION}"
export path_file="hadoop-${HADOOP_VERSION}.tar.gz"

log "Downloading Hadoop ${HADOOP_VERSION}..."
wget -q -O ${path_file} http://mirrors.sonic.net/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

log "Installing Hadoop..."
useradd hadoop || log "User [hadoop] already exists. Continuing..."

install -d -o hadoop -g hadoop ${path_install}
tar -xzf ${path_file} -C /usr/local/

export HADOOP_HOME=${path_install}
/usr/bin/printf "
HADOOP_HOME=${path_install}" >> /etc/environment

rm ${path_file}