#!/usr/bin/env bash
set -ex

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function setup_hive_metastore {

  echo "setup_hive_metastore stub.."

  # Mount persistent storage and apply Hive Metastore schema if needed
  DEVICE_NAME="/dev/disk/azure/scsi1/lun0"
  MOUNT_PATH=/var/lib/mysql


  sudo mv $MOUNT_PATH /tmp/mysql.backup
  sudo mkdir -p $MOUNT_PATH

  if sudo mount -o defaults -t ext4 "$DEVICE_NAME" $MOUNT_PATH; then
    echo 'Successfully mounted existing disk'
  else
    echo 'Trying to mount a fresh disk'
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard "$DEVICE_NAME"
    sudo mount -o defaults -t ext4 "$DEVICE_NAME" $MOUNT_PATH && echo 'Successfully mounted a fresh disk'
    sudo cp -ar /tmp/mysql.backup/* $MOUNT_PATH/
  fi

  sudo chown mysql:mysql -R $MOUNT_PATH
  sudo chmod 700 $MOUNT_PATH

  service mysql start
  systemctl enable mysql

  . /etc/environment
  export HADOOP_HOME=$HADOOP_HOME

  if ! "$HIVE_HOME"/bin/schematool -validate -dbType mysql; then
    echo "Mysql schema is not valid"
    "$HIVE_HOME"/bin/schematool -dbType mysql -initSchema
  fi

  echo "Initializing Hive Metastore ($HIVE_HOME)..."
  service hive-metastore start
  systemctl enable hive-metastore
}



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
-Duser.timezone=UTC
" > /etc/presto/jvm.config


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
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
node-scheduler.include-coordinator=false

http-server.http.port=${http_port}
# query.max-memory-per-node has to be <= query.max-total-memory-per-node
#query.max-memory-per-node=${query_max_memory_per_node}GB
#query.max-total-memory-per-node=${query_max_total_memory_per_node}GB
query.max-memory=${query_max_memory}GB
# query.max-total-memory defaults to query.max-memory * 2 so we are good
${extra_worker_configs}
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
discovery.uri=http://${address_presto_coordinator}:${http_port}
node-scheduler.include-coordinator=false

http-server.http.port=${http_port}
# query.max-memory-per-node has to be <= query.max-total-memory-per-node
#query.max-memory-per-node=${query_max_memory_per_node}GB
#query.max-total-memory-per-node=${query_max_total_memory_per_node}GB
query.max-memory=${query_max_memory}GB
# query.max-total-memory defaults to query.max-memory * 2 so we are good
${extra_worker_configs}
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
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
node-scheduler.include-coordinator=true

http-server.http.port=${http_port}
# query.max-memory-per-node has to be <= query.max-total-memory-per-node
#query.max-memory-per-node=${query_max_memory_per_node}GB
#query.max-total-memory-per-node=${query_max_total_memory_per_node}GB
query.max-memory=${query_max_memory}GB
# query.max-total-memory defaults to query.max-memory * 2 so we are good
${extra_worker_configs}
" > /etc/presto/config.properties

  setup_hive_metastore
fi

if [[ "${mode_presto}" == "worker" ]]; then
  echo "Waiting for Presto Coordinator to come online at: http://${address_presto_coordinator}:${http_port}"
  while ! nc -z ${address_presto_coordinator} ${http_port}; do
      sleep 5
  done
fi


AZURE_ACCOUNT="${az_account_name}"
AZURE_KEY="${az_access_key}"

if [ ! -z "$AZURE_ACCOUNT" ] && [ ! -z "$AZURE_KEY" ]; then
  # Update hive-site.xml
  /usr/bin/printf "<configuration>
  <property>
    <name>fs.azure.account.key.$AZURE_ACCOUNT.blob.core.windows.net</name>
    <value>$AZURE_KEY</value>
  </property>
  " > /tmp/hive-site-partial.txt
  sudo sed -i "s/<configuration>/$(sed 's@[/\&]@\\&@g;$!s/$/\\/' /tmp/hive-site-partial.txt)/g" /usr/local/apache-hive-*-bin/conf/hive-site.xml
  rm /tmp/hive-site-partial.txt

  # Update hive.properties
  /usr/bin/printf "\nhive.allow-drop-table=true" >> /etc/presto/catalog/hive.properties
  /usr/bin/printf "\nhive.non-managed-table-writes-enabled=true" >> /etc/presto/catalog/hive.properties
  /usr/bin/printf "\n#hive.time-zone=UTC" >> /etc/presto/catalog/hive.properties
  /usr/bin/printf "\nhive.hive.azure.wasb-storage-account=$AZURE_ACCOUNT" >> /etc/presto/catalog/hive.properties
  /usr/bin/printf "\nhive.hive.azure.wasb-access-key=$AZURE_KEY" >> /etc/presto/catalog/hive.properties
  /usr/bin/printf "\n" >> /etc/presto/catalog/hive.properties
fi


echo "Starting presto..."
systemctl enable presto.service
systemctl start presto.service

if [[ "${mode_presto}" == "coordinator" ]] || [[ "${mode_presto}" == "coordinator-worker" ]]; then
    echo "Waiting for Presto Coordinator to start"
    while ! presto --execute='select * from system.runtime.nodes'; do
      sleep 10
    done
    echo "Presto Coordinator is now online"
fi


