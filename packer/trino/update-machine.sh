#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export DEBIAN_FRONTEND=noninteractive

TZ=Etc/UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

log "Updating package index..."
sudo -E apt-get update -y -qq

log "Upgrading existing packages"
sudo -E apt-get upgrade -y -qq

log "Updating package index..."
sudo -E apt-get update -y -qq

log "Installing prerequisites..."
sudo -E apt-get install -y -qq --no-install-recommends \
   wget software-properties-common htop apt-transport-https python3 jq awscli vim

sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10

# Disable daily apt unattended updates.
echo 'APT::Periodic::Enable "0";' >> /etc/apt/apt.conf.d/10periodic