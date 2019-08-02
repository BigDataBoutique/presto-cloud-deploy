#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export DEBIAN_FRONTEND=noninteractive

log "Updating package index..."
sudo -E apt-get update -qq

log "Upgrading existing packages"
sudo -E apt-get upgrade -y

log "Installing prerequisites..."
sudo -E apt-get install -y -qq --no-install-recommends \
  build-essential libssl-dev libffi-dev \
  python-dev python3.6-dev python3-pip python3-venv \
  libsasl2-dev libldap2-dev \
  nginx jq xmlstarlet

log "Generating temporary certificates"
mkdir -p /opt/certs
cd /opt/certs
openssl genrsa -des3 -passout pass:xxxx -out keypair 2048
openssl rsa -passin pass:xxxx -in keypair -out server.key
rm keypair
touch /home/ubuntu/.rnd
openssl req -new -key server.key -out server.csr -subj "/CN=*"
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
rm server.csr
cd -

systemctl enable nginx.service
systemctl start nginx.service

sudo mkdir -p /etc/nginx/conf.d
sudo mv /tmp/clients-nginx.conf /etc/nginx/conf.d/clients.conf