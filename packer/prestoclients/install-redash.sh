git clone https://github.com/getredash/setup /tmp/redash
cd /tmp/redash/

#export REDASH_BRANCH="v$REDASH_VERSION"
sed 's/\$LATEST_VERSION/10.1.0.b50633/g' setup.sh > setup2.sh
mv setup2.sh setup.sh
bash ./setup.sh

cd /opt/redash
docker-compose down
sed -i '/^.*nginx:$/,$d' docker-compose.yml # patch out nginx service
docker-compose up -d
