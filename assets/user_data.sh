#!/usr/bin/env bash
set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat <<'EOF' >>/etc/security/limits.conf
presto soft soft nofile 16384
presto hard soft nofile 16384
EOF

/usr/bin/printf "
node.environment=${environment_name}
node.id=$(hostname)
node.data-dir=/var/lib/presto/
" > /etc/presto/node.properties

/usr/bin/printf "-server
-XX:+PrintGC
-XX:+PrintGCDateStamps
-XX:MaxRAM=15500m
-Xmx${heap_size}G
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+UseGCOverheadLimit
-XX:+ExplicitGCInvokesConcurrent
-XX:+UseNUMA
-XX:+AggressiveOpts
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
-Djava.library.path=/usr/local/lib
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
node-scheduler.include-coordinator=false
http-server.http.port=${http_port}
# query.max-memory-per-node has to be <= query.max-total-memory-per-node
query.max-memory-per-node=${memory_size}GB
query.max-total-memory-per-node=${total_memory_size}GB
node-scheduler.max-splits-per-node=48
task.max-partial-aggregation-memory=64MB
query.schedule-split-batch-size=30000
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
" > /etc/presto/config.properties

  echo "Initializing Hive Metastore ($HIVE_HOME)..."
  service mysql start
  systemctl enable mysql
  service hive-metastore start
  systemctl enable hive-metastore
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
query.max-memory=4GB
node-scheduler.max-splits-per-node=24
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
" > /etc/presto/config.properties

  echo "Initializing Hive Metastore ($HIVE_HOME)..."
  service mysql start
  systemctl enable mysql
  service hive-metastore start
  systemctl enable hive-metastore
fi

if [[ "${mode_presto}" == "worker" ]]; then
  echo "Waiting for Presto Coordinator to come online at: http://${address_presto_coordinator}:${http_port}"
  while ! nc -z ${address_presto_coordinator} ${http_port}; do
      sleep 5
  done
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

