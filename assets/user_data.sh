#!/usr/bin/env bash
set -ex

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat <<'EOF' >/etc/security/limits.d/100-trino-nofile.conf
trino soft nofile 131072
trino hard nofile 131072
EOF

/usr/bin/printf "
node.environment=${environment_name}
node.id=$(hostname)
node.data-dir=/var/lib/trino/
" > /etc/trino/node.properties

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
" > /etc/trino/jvm.config

#
# Configure as COORDINATOR
#
if [[ "${mode_trino}" == "coordinator" ]]; then
  # TODO: Bind eip instead of using LB
  echo "Configuring node as a [${mode_trino}]..."

  /usr/bin/printf "
#
# coordinator
#
coordinator=true
discovery-server.enabled=true
discovery.uri=http://localhost:${http_port}
node-scheduler.include-coordinator=false
http-server.http.port=${http_port}
query.max-memory=${query_max_memory}GB
" > /etc/trino/config.properties
fi
#
# Configure as WORKER
#
if [[ "${mode_trino}" == "worker" ]]; then
  echo "Configuring node as a [${mode_trino}]..."

  /usr/bin/printf "
#
# worker
#
coordinator=false
discovery.uri=http://${address_trino_coordinator}:${http_port}
node-scheduler.include-coordinator=false

http-server.http.port=${http_port}
query.max-memory=${query_max_memory}GB
${extra_worker_configs}
" > /etc/trino/config.properties
fi

if [[ "${mode_trino}" == "worker" ]]; then
  echo "Waiting for Trino Coordinator to come online at: http://${address_trino_coordinator}:${http_port}"
  while ! nc -z ${address_trino_coordinator} ${http_port}; do
      sleep 5
  done
fi

echo "Starting trino..."
systemctl enable trino.service
systemctl start trino.service

if [[ "${mode_trino}" == "coordinator" ]] || [[ "${mode_trino}" == "coordinator-worker" ]]; then
    echo "Waiting for Trino Coordinator to start"
    while ! trino --execute='select * from system.runtime.nodes'; do
      sleep 10
    done
    echo "Trino Coordinator is now online"
fi

echo "Executing additional bootstrap scripts"

%{ for script in additional_bootstrap_scripts ~}
  %{ if script.type == "s3" ~}
    aws s3 cp "${script.script_url}" "/tmp/${script.script_name}"
  %{ else ~}
    curl "${script.script_url}" -o "/tmp/${script.script_name}"
  %{ endif ~}
  chmod +x "/tmp/${script.script_name}"
  sh -c "/tmp/${script.script_name} %{ for param in script.params ~} ${param} %{ endfor ~}"
%{ endfor ~}

echo "Restarting Trino service"

systemctl restart trino
