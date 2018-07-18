#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

log "Updating package index..."
sudo apt-get -qq update
sudo rm /boot/grub/menu.lst

log "Upgrading existing packages"
sudo apt-get upgrade -qq -y

log "Installing prerequisites..."
sudo apt-get install -y -qq --no-install-recommends \
   wget software-properties-common htop ntp jq apt-transport-https

# Disable daily apt unattended updates.
echo 'APT::Periodic::Enable "0";' >> /etc/apt/apt.conf.d/10periodic