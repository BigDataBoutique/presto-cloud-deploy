#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

log "Updating package index..."
sudo apt-get -qq update
sudo rm /boot/grub/menu.lst

log "Upgrading existing packages"
sudo apt-get -qq upgrade -y

log "Installing prerequisites..."
sudo apt-get -qq install -y --no-install-recommends \
   wget software-properties-common htop ntp jq apt-transport-https python

# Disable daily apt unattended updates.
echo 'APT::Periodic::Enable "0";' >> /etc/apt/apt.conf.d/10periodic