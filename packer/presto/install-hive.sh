#!/usr/bin/env bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export path_install="/usr/local/apache-hive-${HIVE_VERSION}-bin"
export path_file="hive-${HIVE_VERSION}.tar.gz"
export HIVE_HOME=${path_install}

export path_hadoop="/usr/local/hadoop-${HADOOP_VERSION}"
export path_hadoop_file="hadoop-${HADOOP_VERSION}.tar.gz"
export HADOOP_HOME=${path_hadoop}

log "Downloading Hadoop ${HADOOP_VERSION}..."
wget -q -O ${path_hadoop_file} https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xzf ${path_hadoop_file} -C /usr/local/
rm ${path_hadoop_file}

log "Downloading Hive ${HIVE_VERSION}..."
wget -q -O ${path_file} https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz

log "Installing Hive..."
useradd -m hive || log "User [hive] already exists. Continuing..."

install -d -o hive -g hive ${path_install}
tar -xzf ${path_file} -C /usr/local/
mv hive-site.xml ${path_install}/conf/hive-site.xml
ln -s /usr/share/java/mysql-connector-java.jar ${HIVE_HOME}/lib/mysql-connector-java.jar
cp -n ${HADOOP_HOME}/share/hadoop/tools/lib/* ${HIVE_HOME}/lib/
echo "export JAVA_HOME=$JAVA8_HOME" >> ${path_install}/bin/hive-config.sh
chown -R hive:hive ${path_install}
rm ${path_file}
echo "export PATH=\"\$PATH:${path_install}/bin\"" > /etc/profile.d/apache-hive.sh

/usr/bin/printf "
HADOOP_HOME=${path_hadoop}
HIVE_HOME=${path_install}" >> /etc/environment

install -d -o hive -g hive /tmp/hive
${HADOOP_HOME}/bin/hadoop fs -chmod -R 777 /tmp/hive/

log "Setup MySQL backend for Hive Metastore..."
sudo debconf-set-selections <<< 'mysql-server-5.6 mysql-server/root_password password pwd'
sudo debconf-set-selections <<< 'mysql-server-5.6 mysql-server/root_password_again password pwd'
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mysql-server libmysql-java

# Disable the mysql service - we will only need it on the coordinator node
systemctl disable mysql

log "Installing the Hive Metastore service"
/usr/bin/printf "[Unit]
Description=Hive Metastore
After=network-online.target
[Service]
User=root
Restart=on-failure
Type=simple
Environment="HADOOP_HOME=${HADOOP_HOME}" "JAVA_HOME=${JAVA_8_HOME}" "HIVE_HOME=${HIVE_HOME}"
ExecStart=${HIVE_HOME}/bin/hive --service metastore
[Install]
WantedBy=default.target
" > /etc/systemd/system/hive-metastore.service