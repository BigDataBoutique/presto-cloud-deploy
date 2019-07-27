#!/usr/bin/env bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

### Redash 

export COMPOSE_INTERACTIVE_NO_CLI=1
cd /opt/redash
sudo -E docker-compose exec -T server ./manage.py users create_root admin@redash admin --password "${admin_password}"
sudo -E docker-compose exec -T server ./manage.py ds new presto --type presto --options '{"host": "${presto_coordinator_host}", "username": "admin"}'

# Redash OAuth setup
# See https://redash.io/help/open-source/admin-guide/google-developer-account-setup
#cat <<'EOF' >/opt/redash/env
#REDASH_GOOGLE_CLIENT_ID=#
#REDASH_GOOGLE_CLIENT_SECRET=#
#EOF
#docker-compose up -d server

cd -

### Apache Superset

. /etc/environment
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

# Presto OAuth setup
# See https://superset.incubator.apache.org/faq.html?highlight=oauth#how-can-i-configure-oauth-authentication-and-authorization
#cat <<'EOF' >/opt/superset/config/superset_config.py
#AUTH_TYPE = AUTH_OAUTH
#
#OAUTH_PROVIDERS = [
#    {
#        "name": "twitter",
#        "icon": "fa-twitter",
#        "remote_app": {
#            "consumer_key": os.environ.get("TWITTER_KEY"),
#            "consumer_secret": os.environ.get("TWITTER_SECRET"),
#            "base_url": "https://api.twitter.com/1.1/",
#            "request_token_url": "https://api.twitter.com/oauth/request_token",
#            "access_token_url": "https://api.twitter.com/oauth/access_token",
#            "authorize_url": "https://api.twitter.com/oauth/authenticate",
#        },
#    },
#    {
#        "name": "google",
#        "icon": "fa-google",
#        "token_key": "access_token",
#        "remote_app": {
#            "consumer_key": os.environ.get("GOOGLE_KEY"),
#            "consumer_secret": os.environ.get("GOOGLE_SECRET"),
#            "base_url": "https://www.googleapis.com/oauth2/v2/",
#            "request_token_params": {"scope": "email profile"},
#            "request_token_url": None,
#            "access_token_url": "https://accounts.google.com/o/oauth2/token",
#            "authorize_url": "https://accounts.google.com/o/oauth2/auth",
#        },
#    },
#    {
#        "name": "azure",
#        "icon": "fa-windows",
#        "token_key": "access_token",
#        "remote_app": {
#            "consumer_key": os.environ.get("AZURE_APPLICATION_ID"),
#            "consumer_secret": os.environ.get("AZURE_SECRET"),
#            "base_url": "https://login.microsoftonline.com/{AZURE_TENANT_ID}/oauth2",
#            "request_token_params": {
#                "scope": "User.read name preferred_username email profile",
#                "resource": os.environ.get("AZURE_APPLICATION_ID"),
#            },
#            "request_token_url": None,
#            "access_token_url": "https://login.microsoftonline.com/{AZURE_TENANT_ID}/oauth2/token",
#            "authorize_url": "https://login.microsoftonline.com/{AZURE_TENANT_ID}/oauth2/authorize",
#        },
#    }
#]
#EOF

nohup gunicorn -w 10 \
      -k gevent \
      --timeout 120 \
      -b  0.0.0.0:8080 \
      --limit-request-line 0 \
      --limit-request-field_size 0 \
      superset:app &