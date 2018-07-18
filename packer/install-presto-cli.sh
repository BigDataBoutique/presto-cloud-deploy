#!/usr/bin/env bash
set -e

log() {
  echo "==> $(basename ${0}): ${1}"
}

export version_presto=${PRESTO_VERSION}
export path_install="/usr/local/presto-cli-${version_presto}"
export path_file="presto-cli-${version_presto}-executable.jar"

log "Downloading Presto CLI ${version_presto}..."
wget -q -O ${path_file} "https://repo1.maven.org/maven2/com/facebook/presto/presto-cli/${version_presto}/presto-cli-${version_presto}-executable.jar"

log "Installing Presto CLI ${version_presto}..."

install -d -o presto -g presto ${path_install}
mv ${path_file} ${path_install}/presto
chmod +x ${path_install}/presto