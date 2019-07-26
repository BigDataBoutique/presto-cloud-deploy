#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

DEBIAN_FRONTEND=noninteractive

TZ=Etc/UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

log "Updating package index..."
sudo apt-get update -qq

log "Upgrading existing packages"
sudo apt-get upgrade -y -qq

log "Installing prerequisites..."
sudo apt-get install -y -qq --no-install-recommends \
   wget software-properties-common htop ntp jq apt-transport-https python

# Disable daily apt unattended updates.
echo 'APT::Periodic::Enable "0";' >> /etc/apt/apt.conf.d/10periodic