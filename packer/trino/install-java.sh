#!/bin/bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

sudo apt-get install gnupg ca-certificates curl
curl -s https://repos.azul.com/azul-repo.key | sudo gpg --dearmor -o /usr/share/keyrings/azul.gpg
echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" | sudo tee /etc/apt/sources.list.d/zulu.list

sudo apt-get update

sudo apt-get install -y zulu17-jdk
