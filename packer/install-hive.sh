#!/usr/bin/env bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export path_install="/usr/local/apache-hive-${HIVE_VERSION}-bin"
export path_config="/etc/hive/metastore_db/"
export path_file="hive-${HIVE_VERSION}.tar.gz"

log "Downloading Hive ${HIVE_VERSION}..."
wget -q -O ${path_file} http://mirrors.sonic.net/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz

log "Installing Hive..."
useradd hive || log "User [hive] already exists. Continuing..."

install -d -o hive -g hive ${path_install}
install -d -o hive -g hive ${path_config}
tar -xzf ${path_file} -C /usr/local/

export HIVE_HOME=${path_install}
/usr/bin/printf "
HIVE_HOME=${path_install}" >> /etc/environment

rm ${path_file}

log "Setup Hive..."
${HIVE_HOME}/bin/schematool -dbType derby -initSchema