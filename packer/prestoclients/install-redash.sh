git clone https://github.com/getredash/setup /tmp/redash
cd /tmp/redash/

export REDASH_BRANCH="v$REDASH_VERSION"
bash ./setup.sh

cd /opt/redash
docker-compose down
sed -i '/^.*nginx:$/,$d' docker-compose.yml # patch out nginx service
docker-compose up -d
