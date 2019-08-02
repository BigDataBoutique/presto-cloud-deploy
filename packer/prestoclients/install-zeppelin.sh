cd /tmp
wget https://www-eu.apache.org/dist/zeppelin/zeppelin-0.8.1/zeppelin-0.8.1-bin-all.tgz
sudo tar xf zeppelin-*-bin-all.tgz -C /opt
rm zeppelin-0.8.1-bin-all.tgz
sudo mv /opt/zeppelin-*-bin-all /opt/zeppelin
sudo cp zeppelin-interpreter-partial.json /opt/zeppelin/conf/zeppelin-interpreter-partial.json

# avoiding issues on >=0.180 versions of presto-jdbc
# https://groups.google.com/forum/#!topic/presto-users/koT1Yv3sKG4
sudo wget https://repo1.maven.org/maven2/com/facebook/presto/presto-jdbc/0.170/presto-jdbc-0.170.jar -P /opt/zeppelin/interpreter/jdbc

sudo useradd -d /opt/zeppelin -s /bin/false zeppelin

/usr/bin/printf "
export JAVA_HOME=$JAVA8_HOME
export ZEPPELIN_PORT=9090
" >> /opt/zeppelin/conf/zeppelin-env.sh

/usr/bin/printf "
[Unit]
Description=Zeppelin service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/zeppelin/bin/zeppelin-daemon.sh start
ExecStop=/opt/zeppelin/bin/zeppelin-daemon.sh stop
ExecReload=/opt/zeppelin/bin/zeppelin-daemon.sh reload
User=zeppelin
Group=zeppelin
Restart=always

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/zeppelin.service

sudo chown -R zeppelin:zeppelin /opt/zeppelin
sudo systemctl enable zeppelin