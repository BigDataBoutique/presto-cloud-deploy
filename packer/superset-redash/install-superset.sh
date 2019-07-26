SUPERSET_DATA_PATH="/opt/superset/data"
SUPERSET_VENV_PATH="/opt/superset/venv"
SUPERSET_CONFIG_PATH="/opt/superset/config"

sudo mkdir -p $SUPERSET_CONFIG_PATH
sudo mkdir -p $SUPERSET_DATA_PATH
sudo chown -R ubuntu:ubuntu $SUPERSET_DATA_PATH

echo >> /etc/environment
echo "SUPERSET_HOME=$SUPERSET_DATA_PATH" >> /etc/environment
export SUPERSET_HOME=$SUPERSET_DATA_PATH

python3 -m venv $SUPERSET_VENV_PATH
. $SUPERSET_VENV_PATH/bin/activate

pip install --upgrade setuptools pip

pip install superset gevent # gevent required for gunicorn

# See https://github.com/apache/incubator-superset/issues/6770
pip install pandas==0.23.4

# See https://github.com/apache/incubator-superset/issues/6977
pip install sqlalchemy==1.2.18

# exit virtualenv
deactivate

/usr/bin/printf "SUPERSET_OPTS= \
      -w 10 \
      -k gevent \
      --timeout 120 \
      -b  0.0.0.0:8080 \
      --limit-request-line 0 \
      --limit-request-field_size 0 \
      superset:app
" >> /etc/default/superset
chown ubuntu:ubuntu /etc/default/superset

/usr/bin/printf "
[Unit]
Description=Superset service 
After=network.target

[Service]
Type=simple
User=ubuntu 
Group=ubuntu 
Environment=PATH=$SUPERSET_VENV_PATH/bin:$PATH
Environment=PYTHONPATH=$SUPERSET_CONFIG_PATH:$SUPERSET_VENV_PATH:$PYTHONPATH
EnvironmentFile=/etc/default/superset
ExecStart=$SUPERSET_VENV_PATH/bin/gunicorn \$SUPERSET_OPTS

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/superset.service

systemctl daemon-reload