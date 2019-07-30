cd /tmp
wget https://www-eu.apache.org/dist/zeppelin/zeppelin-0.8.1/zeppelin-0.8.1-bin-all.tgz
sudo tar xf zeppelin-*-bin-all.tgz -C /opt
rm zeppelin-0.8.1-bin-all.tgz
sudo mv /opt/zeppelin-*-bin-all /opt/zeppelin

sudo useradd -d /opt/zeppelin -s /bin/false zeppelin
sudo chown -R zeppelin:zeppelin /opt/zeppelin

echo "JAVA_HOME=$JAVA8_HOME" | sudo tee /opt/zeppelin/conf/zeppelin-env.sh

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

sudo systemctl enable zeppelin