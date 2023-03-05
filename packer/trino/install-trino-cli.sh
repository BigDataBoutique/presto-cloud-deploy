#!/usr/bin/env bash
set -eux

log() {
  echo "==> $(basename ${0}): ${1}"
}

export version_trino=${TRINO_VERSION}
export path_install="/usr/local/bin"
export path_file="trino-cli-${version_trino}-executable.jar"

log "Downloading Trino CLI ${version_trino}..."

wget -q -O ${path_file} "https://repo1.maven.org/maven2/io/trino/trino-cli/${version_trino}/trino-cli-${version_trino}-executable.jar"

log "Installing Trino CLI ${version_trino}..."

install -d -o trino -g trino ${path_install}
mv ${path_file} ${path_install}/trino
chmod +x ${path_install}/trino
