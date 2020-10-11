SUPERSET_DATA_PATH="/opt/superset/data"
SUPERSET_VENV_PATH="/opt/superset/venv"
SUPERSET_CONFIG_PATH="/opt/superset/config"

sudo mkdir -p $SUPERSET_CONFIG_PATH
sudo mkdir -p $SUPERSET_DATA_PATH
sudo chown -R ubuntu:ubuntu $SUPERSET_DATA_PATH

echo >> /etc/environment
echo "SUPERSET_HOME=$SUPERSET_DATA_PATH" >> /etc/environment
echo "PYTHONPATH=$SUPERSET_CONFIG_PATH:$PYTHONPATH" >> /etc/environment
export SUPERSET_HOME=$SUPERSET_DATA_PATH

git clone --depth 1 https://github.com/apache/incubator-superset /tmp/incubator-superset

apt-get install python3-venv
python3 -m venv $SUPERSET_VENV_PATH
. $SUPERSET_VENV_PATH/bin/activate

pip install --upgrade setuptools pip
pip install -r /tmp/incubator-superset/requirements.txt \
            -r /tmp/incubator-superset/requirements-dev.txt \
            -r /tmp/incubator-superset/contrib/docker/requirements-extra.txt

# See https://github.com/apache/incubator-superset/issues/6770
pip install pandas==0.23.4

# See https://github.com/apache/incubator-superset/issues/6977
pip install sqlalchemy==1.2.18

pip install superset gevent

rm -rf /tmp/incubator-superset

cat <<'EOF' >$SUPERSET_CONFIG_PATH/presto-datasource.yaml
databases:
- database_name: presto
  expose_in_sqllab: true
  extra: "{\r\n    \"metadata_params\": {},\r\n    \"engine_params\": {},\r\n    \"\
    metadata_cache_timeout\": {},\r\n    \"schemas_allowed_for_csv_upload\": []\r\n\
    }\r\n"
  sqlalchemy_uri: presto://PRESTO_COORDINATOR_HOST
  tables: []
EOF

cat <<'EOF' >$SUPERSET_CONFIG_PATH/superset_config.py
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'
EOF
