#!/usr/bin/env bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

### SSL Certs
mkdir -p /opt/certs
cat <<'EOF' >/opt/certs/server.crt
${cert_pem}
EOF
cat <<'EOF' >/opt/certs/server.key
${key_pem}
EOF
cat <<'EOF' >/etc/nginx/conf.d/clients.conf
${nginx_conf}
EOF
cat <<'EOF' >/tmp/presto_zeppelin_interpreter.json
${presto_zeppelin_interp}
EOF


### Redash 

export COMPOSE_INTERACTIVE_NO_CLI=1
cd /opt/redash
sudo -E docker-compose exec -T server ./manage.py users create_root admin@redash admin --password "${admin_password}"
sudo -E docker-compose exec -T server ./manage.py ds new presto --type presto --options '{"host": "${presto_coordinator_host}", "username": "admin"}'

# Patch nginx out of docker-compose
sed -i '/^.*nginx:$/,$d' docker-compose.yml

# Redash OAuth setup
# See https://redash.io/help/open-source/admin-guide/google-developer-account-setup
#cat <<'EOF' >/opt/redash/env
#REDASH_GOOGLE_CLIENT_ID=#
#REDASH_GOOGLE_CLIENT_SECRET=#
#EOF
#docker-compose up -d server

docker-compose down
docker-compose up -d

cd -

### Zeppelin
/usr/bin/printf "[users]
admin = ${admin_password}, admin
[main]
sessionManager = org.apache.shiro.web.session.mgt.DefaultWebSessionManager
cookie = org.apache.shiro.web.servlet.SimpleCookie
cookie.name = JSESSIONID
cookie.httpOnly = true
sessionManager.sessionIdCookie = \$cookie
securityManager.sessionManager = \$sessionManager
securityManager.sessionManager.globalSessionTimeout = 86400000
shiro.loginUrl = /api/login
[roles]
admin = *
[urls]
/api/version = anon
/api/interpreter/setting/restart/** = authc
/api/interpreter/** = authc, roles[admin]
/api/configurations/** = authc, roles[admin]
/api/credential/** = authc, roles[admin]
/** = authc
" | sudo tee /opt/zeppelin/conf/shiro.ini

xmlstarlet ed \
  -u "//property[name='zeppelin.anonymous.allowed']/value" \
  -v false < /opt/zeppelin/conf/zeppelin-site.xml.template | sudo tee /opt/zeppelin/conf/zeppelin-site.xml


sudo wget https://repo1.maven.org/maven2/com/facebook/presto/presto-jdbc/0.170/presto-jdbc-0.170.jar -P /opt/zeppelin/interpreter/jdbc
#sudo wget https://repo1.maven.org/maven2/com/facebook/presto/presto-jdbc/0.223/presto-jdbc-0.223.jar -P /opt/zeppelin/interpreter/jdbc

cat /opt/zeppelin/conf/interpreter.json | jq --argfile presto /tmp/presto_zeppelin_interpreter.json '.interpreterSettings.presto = $presto' > /tmp/interpreter.json
sudo mv /tmp/interpreter.json /opt/zeppelin/conf/interpreter.json

sudo service zeppelin start

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

cat <<'EOF' >/opt/superset/config/superset_config.py
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'
EOF

# Presto OAuth setup
# See https://superset.incubator.apache.org/faq.html?highlight=oauth#how-can-i-configure-oauth-authentication-and-authorization
#cat <<'EOF' >>/opt/superset/config/superset_config.py
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
      -b  localhost:6000 \
      --limit-request-line 0 \
      --limit-request-field_size 0 \
      --forwarded-allow-ips="*" \
      superset:app &

sudo systemctl restart nginx.service