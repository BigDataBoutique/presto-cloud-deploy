#!/usr/bin/env bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export path_install="/usr/local/apache-hive-${HIVE_VERSION}-bin"

export path_file="hive-${HIVE_VERSION}.tar.gz"

log "Downloading Hive ${HIVE_VERSION}..."
wget -q -O ${path_file} http://mirrors.sonic.net/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz

log "Installing Hive..."
useradd -m hive || log "User [hive] already exists. Continuing..."

install -d -o hive -g hive ${path_install}
tar -xzf ${path_file} -C /usr/local/
mv hive-site.xml ${path_install}/conf/hive-site.xml
chown -R hive:hive ${path_install}

install -d -o hive -g hive /tmp/hive
${HADOOP_HOME}/bin/hadoop fs -chmod -R 777 /tmp/hive/

export HIVE_HOME=${path_install}
/usr/bin/printf "
HIVE_HOME=${path_install}" >> /etc/environment

rm ${path_file}

log "Setup MySQL backend for Hive Metastore..."
sudo debconf-set-selections <<< 'mysql-server-5.6 mysql-server/root_password password pwd'
sudo debconf-set-selections <<< 'mysql-server-5.6 mysql-server/root_password_again password pwd'
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mysql-server libmysql-java

log "Setup Hive Metastore..."
service mysql start
ln -s /usr/share/java/mysql-connector-java.jar ${HIVE_HOME}/lib/mysql-connector-java.jar
${HIVE_HOME}/bin/schematool -dbType mysql -initSchema
service mysql stop


log "Installing the Hive Metastore service"
/usr/bin/printf "[Unit]
Description=Hive Metastore
After=network-online.target
[Service]
User=root
Restart=on-failure
Type=simple
Environment="HADOOP_HOME=${HADOOP_HOME}" "JAVA_HOME=${JAVA_HOME}" "HIVE_HOME=${HIVE_HOME}"
ExecStart=${HIVE_HOME}/bin/hive --service metastore
[Install]
WantedBy=default.target
" > /etc/systemd/system/hive-metastore.service