git clone --depth 1 --branch v$REDASH_VERSION https://github.com/getredash/redash.git /tmp/redash
cd /tmp/redash/setup
bash ./setup.sh

cd /opt/redash
docker-compose down
sed -i '/^.*nginx:$/,$d' docker-compose.yml # patch out nginx service
docker-compose up -d

systemctl start nginx.service