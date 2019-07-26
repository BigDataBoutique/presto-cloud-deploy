#!/usr/bin/env bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

### Redash 

export COMPOSE_INTERACTIVE_NO_CLI=1
cd /opt/redash
sudo -E docker-compose exec -T server ./manage.py users create_root admin@redash admin --password "${admin_password}"
sudo -E docker-compose exec -T server ./manage.py ds new presto --type presto --options '{"host": "${presto_coordinator_host}", "username": "admin"}'
cd -

### Apache Superset

. /opt/superset/venv/bin/activate

superset db upgrade
export FLASK_APP=superset
flask fab create-admin --username admin --password ${admin_password} --firstname "" --lastname "" --email ""
superset init

# Create presto datasource
cat <<'EOF' >/tmp/presto-datasource.yaml
databases:
- database_name: presto
  extra: "{\r\n    \"metadata_params\": {},\r\n    \"engine_params\": {},\r\n    \"\
    metadata_cache_timeout\": {},\r\n    \"schemas_allowed_for_csv_upload\": []\r\n\
    }\r\n"
  sqlalchemy_uri: presto://${presto_coordinator_host}
  tables: []
EOF
superset import_datasources -p /tmp/presto-datasource.yaml
rm /tmp/presto-datasource.yaml

# Start Superset
nohup gunicorn \
      -w 10 \
      -k gevent \
      --timeout 120 \
      -b  0.0.0.0:8080 \
      --limit-request-line 0 \
      --limit-request-field_size 0 \
      superset:app &
