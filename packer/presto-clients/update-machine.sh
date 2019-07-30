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
   build-essential libssl-dev libffi-dev python-dev python3.6-dev python3-pip python3-venv libsasl2-dev libldap2-dev nginx jq xmlstarlet

systemctl enable nginx.service
systemctl stop nginx.service