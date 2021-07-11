#!/usr/bin/env bash
set -ex

log() {
  echo "==> $(basename ${0}): ${1}"
}

export version_trino=${PRESTO_VERSION}
export path_install="/usr/local/trino-server-${version_trino}"
export path_file="trino-server-${version_trino}.tar.gz"
export pid_file="/var/run/trino/trino.pid"
export user_trino='trino'

log "Downloading Presto ${version_trino}..."

wget -q -O "${path_file}" "https://repo1.maven.org/maven2/io/trino/trino-server/${version_trino}/trino-server-${version_trino}.tar.gz"

log "Installing Presto / Trino ${version_trino}..."
useradd ${user_trino} || log "User [${user_trino}] already exists. Continuing..."

install -d -o ${user_trino} -g ${user_trino} "${path_install}"
tar -xzf "${path_file}" -C /usr/local/
install -d -o ${user_trino} -g ${user_trino} /etc/trino/
install -d -o ${user_trino} -g ${user_trino} /etc/trino/catalog
install -d -o ${user_trino} -g ${user_trino} /var/lib/trino/ # this is the data dir
install -d -o ${user_trino} -g ${user_trino} /var/log/trino/
mv ./presto-catalogs/* /etc/trino/catalog/
rm -rf ./presto-catalogs
rm -rf "$path_install/etc"
ln -s /etc/trino/ "$path_install/etc"

log "Adding TRINO_HOME to system profile"
/usr/bin/printf "export TRINO_HOME=\"${path_install}\"" >> /etc/profile.d/trino.sh



/usr/bin/printf "TRINO_OPTS= \
--pid-file=${pid_file} \
--node-config=/etc/trino/node.properties \
--jvm-config=/etc/trino/jvm.config \
--config=/etc/trino/config.properties \
--launcher-log-file=/var/log/trino/launcher.log \
--server-log-file=/var/log/trino/server.log \
-Dhttp-server.log.path=/var/log/trino/http-request.log \
-Dcatalog.config-dir=/etc/trino/catalog
[Install]
WantedBy=default.target
" >> /etc/default/trino
chown ${user_trino}:${user_trino} /etc/default/trino

log "Installing the Presto service"
/usr/bin/printf "
[Unit]
Description=Presto Server
Documentation=https://trino.io/docs/current/index.html
After=network-online.target
[Service]
User=${user_trino}
Restart=on-failure
Type=forking
PIDFile=${pid_file}
RuntimeDirectory=trino
EnvironmentFile=/etc/default/trino
ExecStart=${path_install}/bin/launcher start \$TRINO_OPTS
ExecStop=${path_install}/bin/launcher stop \$TRINO_OPTS
[Install]
WantedBy=default.target
" > /etc/systemd/system/trino.service

systemctl daemon-reload

rm "${path_file}"
