#!/usr/bin/env bash
set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat <<'EOF' >/etc/security/limits.d/100-presto-nofile.conf
presto soft nofile 16384
presto hard nofile 16384
EOF

/usr/bin/printf "
node.environment=${environment_name}
node.id=$(hostname)
node.data-dir=/var/lib/presto/
" > /etc/presto/node.properties

/usr/bin/printf "-server
-Xmx${heap_size}G
-XX:-UseBiasedLocking
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
-XX:+UseGCOverheadLimit
-XX:ReservedCodeCacheSize=512M
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
" > /etc/presto/jvm.config

function setup_hive_metastore {
  # Mount persistent storage and apply Hive Metastore schema if needed

  DEVICE_NAME=$(lsblk -ip | tail -n +2 | awk '{print $1 " " ($7? "MOUNTEDPART" : "") }' | sed ':a;N;$!ba;s/\n`/ /g' | grep -v MOUNTEDPART)
  MOUNT_PATH=/var/lib/mysql

  sudo mv $MOUNT_PATH /tmp/mysql.backup 
  sudo mkdir -p $MOUNT_PATH

  if sudo mount -o defaults -t ext4 $DEVICE_NAME $MOUNT_PATH; then
    echo 'Successfully mounted existing disk'
  else
    echo 'Trying to mount a fresh disk'
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard $DEVICE_NAME
    sudo mount -o defaults -t ext4 $DEVICE_NAME $MOUNT_PATH && echo 'Successfully mounted a fresh disk'
    sudo cp -ar /tmp/mysql.backup/* $MOUNT_PATH/
  fi

  sudo chown mysql:mysql -R $MOUNT_PATH
  sudo chmod 700 $MOUNT_PATH

  service mysql start
  systemctl enable mysql

  . /etc/environment
  export HADOOP_HOME=$HADOOP_HOME

  if ! $HIVE_HOME/bin/schematool -validate -dbType mysql; then
    echo "Mysql schema is not valid"
    $HIVE_HOME/bin/schematool -dbType mysql -initSchema
  fi

  echo "Initializing Hive Metastore ($HIVE_HOME)..."
  service hive-metastore start
  systemctl enable hive-metastore
}

#
# Configure as COORDINATOR
#
if [[ "${mode_presto}" == "coordinator" ]]; then
  echo "Configuring node as a [${mode_presto}]..."

  /usr/bin/printf "
#
# coordinator
#
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=${http_port}
query.max-memory=${query_max_memory}
# query.max-memory-per-node has to be <= query.max-total-memory-per-node
query.max-memory-per-node=${memory_size}GB
query.max-total-memory-per-node=${total_memory_size}GB
node-scheduler.max-splits-per-node=48
task.max-partial-aggregation-memory=64MB
query.schedule-split-batch-size=30000
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
" > /etc/presto/config.properties

  setup_hive_metastore
fi

#
# Configure as WORKER
#
if [[ "${mode_presto}" == "worker" ]]; then
  echo "Configuring node as a [${mode_presto}]..."

  /usr/bin/printf "
#
# worker
#
coordinator=false
http-server.http.port=${http_port}
query.max-memory=${query_max_memory}
query.max-memory-per-node=${memory_size}GB
query.max-total-memory-per-node=${total_memory_size}GB
memory.heap-headroom-per-node=8GB
node-scheduler.max-splits-per-node=48
task.max-partial-aggregation-memory=64MB
query.schedule-split-batch-size=30000
discovery.uri=http://${address_presto_coordinator}:${http_port}
" > /etc/presto/config.properties
fi

#
# Configure as BOTH coordinator and worker
#
if [[ "${mode_presto}" == "coordinator-worker" ]]; then
  echo "Configuring node as a [${mode_presto}]..."

  /usr/bin/printf "
#
# coordinator-worker
#
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=${http_port}
query.max-memory=${query_max_memory}
node-scheduler.max-splits-per-node=24
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
" > /etc/presto/config.properties

  setup_hive_metastore
fi

if [[ "${mode_presto}" == "worker" ]]; then
  echo "Waiting for Presto Coordinator to come online at: http://${address_presto_coordinator}:${http_port}"
  while ! nc -z ${address_presto_coordinator} ${http_port}; do
      sleep 5
  done
fi

if [ ! -z "${aws_access_key_id}" ] && [ ! -z "${aws_secret_access_key}" ]; then
  # Update hive-site.xml
  /usr/bin/printf "<configuration>
  <property>
  <name>fs.s3.awsAccessKeyId</name>
  <value>${aws_access_key_id}</value>
  </property>
  <property>
  <name>fs.s3.awsSecretAccessKey</name>
  <value>${aws_secret_access_key}</value>
  </property>" > /tmp/hive-site-partial.txt
  sudo sed -i "s/<configuration>/$(sed 's@[/\&]@\\&@g;$!s/$/\\/' /tmp/hive-site-partial.txt)/g" /usr/local/apache-hive-*-bin/conf/hive-site.xml
  rm /tmp/hive-site-partial.txt

  # Update hive.properties
  sed -i -E "s/^#hive.s3.aws-access-key.+$/hive.s3.aws-access-key=${aws_access_key_id}/g" /etc/presto/catalog/hive.properties
  sed -i -E "s/^#hive.s3.aws-secret-key.+$/hive.s3.aws-secret-key=${aws_secret_access_key}/g" /etc/presto/catalog/hive.properties
fi

echo "Starting presto..."
systemctl enable presto.service
systemctl start presto.service

if [[ "${mode_presto}" == "coordinator" ]]; then
    echo "Waiting for Presto Coordinator to start"
    while ! nc -z localhost ${http_port}; do
      sleep 5
    done
    echo "Presto Coordinator is now online"
fi
