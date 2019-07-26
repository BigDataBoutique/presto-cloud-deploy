#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

wait_lock() {
  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    log "Waiting for other software managers to finish..." 
    sleep 5
  done 
}

export DEBIAN_FRONTEND=noninteractive


log "Updating package index..."
wait_lock
sudo -E apt-get update -qq

log "Upgrading existing packages"
wait_lock
sudo -E apt-get upgrade -y

log "Installing prerequisites..."
sudo -E apt-get install -y -qq --no-install-recommends \
   build-essential libssl-dev libffi-dev python-dev python3.6-dev python3-pip python3-venv libsasl2-dev libldap2-dev