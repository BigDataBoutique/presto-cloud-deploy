SUPERSET_DATA_PATH="/opt/superset/data"
SUPERSET_VENV_PATH="/opt/superset/venv"

sudo mkdir -p $SUPERSET_DATA_PATH
sudo chown -R ubuntu:ubuntu $SUPERSET_DATA_PATH

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