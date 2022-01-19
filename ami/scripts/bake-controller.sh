#!/usr/bin/env bash
set -euo pipefail

DOCKER_VERSION="5:20.10.9*"

cloud-init status -w

sudo apt-get update && \
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    jq \
    python3-pip \
    software-properties-common \
  && \
  rm -rf /var/lib/apt/lists/*

cloud-init clean -s -l

sudo tee /etc/pip.conf << EOF
[global]
disable-pip-version-check = 1
EOF

sudo chmod 0644 /etc/pip.conf

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo apt-key add -

sudo add-apt-repository "deb [arch=amd64] \
  https://download.docker.com/linux/ubuntu \
  $(lsb release -cs) \
  stable"

sudo tee /etc/apt/preferences.d/docker-ce << EOF
Package: docker-ce
Pin: version ${DOCKER_VERSION}
Pin-Priority: 1002

Package: docker-ce-cli
Pin: version ${DOCKER_VERSION}
Pin-Priority: 1002
EOF

sudo apt-get install docker-ce

sudo tee /etc/docker/daemon.json << EOF
{
    "log-driver": "journald",
    "storage-driver": "overlay2"
}
EOF
