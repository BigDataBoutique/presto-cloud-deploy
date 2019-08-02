#!/usr/bin/env bash
set -e

# Based on the official Presto installation instructions found at https://prestodb.io/docs/current/installation/deployment.html
# Using code taken from https://github.com/joyent/terraform-triton-presto/blob/master/packer/scripts/install_presto.sh

log() {
  echo "==> $(basename ${0}): ${1}"
}

export version_presto=${PRESTO_VERSION}
export path_install="/usr/local/presto-server-${version_presto}"
export path_file="presto-server-${version_presto}.tar.gz"
export pid_file="/var/run/presto/presto.pid"
export user_presto='presto'

log "Downloading Presto ${version_presto}..."

wget -q -O ${path_file} "https://repo1.maven.org/maven2/io/prestosql/presto-server/${version_presto}/presto-server-${version_presto}.tar.gz"

log "Installing Presto ${version_presto}..."
useradd ${user_presto} || log "User [${user_presto}] already exists. Continuing..."

install -d -o ${user_presto} -g ${user_presto} ${path_install}
tar -xzf ${path_file} -C /usr/local/
install -d -o ${user_presto} -g ${user_presto} /etc/presto/
install -d -o ${user_presto} -g ${user_presto} /etc/presto/catalog
install -d -o ${user_presto} -g ${user_presto} /var/lib/presto/ # this is the data dir
install -d -o ${user_presto} -g ${user_presto} /var/log/presto/
mv ./presto-catalogs/* /etc/presto/catalog/
rm -rf ./presto-catalogs

/usr/bin/printf "PRESTO_OPTS= \
--pid-file=${pid_file} \
--node-config=/etc/presto/node.properties \
--jvm-config=/etc/presto/jvm.config \
--config=/etc/presto/config.properties \
--launcher-log-file=/var/log/presto/launcher.log \
--server-log-file=/var/log/presto/server.log \
-Dhttp-server.log.path=/var/log/presto/http-request.log \
-Dcatalog.config-dir=/etc/presto/catalog
[Install]
WantedBy=default.target
" >> /etc/default/presto
chown ${user_presto}:${user_presto} /etc/default/presto

log "Installing the Presto service"
/usr/bin/printf "
[Unit]
Description=Presto Server
Documentation=https://prestodb.io/docs/current/index.html
After=network-online.target
[Service]
User=${user_presto}
Restart=on-failure
Type=forking
PIDFile=${pid_file}
RuntimeDirectory=presto
EnvironmentFile=/etc/default/presto
ExecStart=${path_install}/bin/launcher start \$PRESTO_OPTS
ExecStop=${path_install}/bin/launcher stop \$PRESTO_OPTS
[Install]
WantedBy=default.target
" > /etc/systemd/system/presto.service

systemctl daemon-reload

rm ${path_file}
