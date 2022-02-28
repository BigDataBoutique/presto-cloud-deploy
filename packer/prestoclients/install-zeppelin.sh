cd /tmp
wget --no-verbose https://www-eu.apache.org/dist/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0-bin-all.tgz
sudo tar xf zeppelin-*-bin-all.tgz -C /opt
rm zeppelin-0.11.0-bin-all.tgz
sudo mv /opt/zeppelin-*-bin-all /opt/zeppelin
sudo cp zeppelin-interpreter-partial.json /opt/zeppelin/conf/zeppelin-interpreter-partial.json

sudo cp zeppelin-jdbc-0.11.0-SNAPSHOT.jar /opt/zeppelin/interpreter/jdbc/zeppelin-jdbc-0.10.0.jar
# trino support for 358 and above
# https://issues.apache.org/jira/browse/ZEPPELIN-5551
sudo wget --no-verbose https://repo1.maven.org/maven2/io/trino/trino-jdbc/370/trino-jdbc-370.jar -P /opt/zeppelin/interpreter/jdbc


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
