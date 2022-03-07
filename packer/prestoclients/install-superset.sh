SUPERSET_CONFIG_PATH="/opt/superset/config"

git clone https://github.com/apache/superset.git /opt/superset

sudo mkdir -p $SUPERSET_CONFIG_PATH

cat <<'EOF' >$SUPERSET_CONFIG_PATH/presto-datasource.yaml
databases:
- database_name: trino
  expose_in_sqllab: true
  extra: "{\r\n    \"metadata_params\": {},\r\n    \"engine_params\": {},\r\n    \"\
    metadata_cache_timeout\": {},\r\n    \"schemas_allowed_for_csv_upload\": []\r\n\
    }\r\n"
  sqlalchemy_uri: trino://trino@PRESTO_COORDINATOR_HOST:8080
  tables: []
EOF

cat <<'EOF' >$SUPERSET_CONFIG_PATH/superset_config.py
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'
EOF

cd /opt/superset
docker-compose -f docker-compose-non-dev.yml pull
