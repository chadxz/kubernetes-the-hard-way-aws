#!/usr/bin/env bash
set -euo pipefail

sudo cloud-init status -w
sudo cloud-init clean -s -l

DOCKER_VERSION="20.10.7"
sudo amazon-linux-extras enable docker
sudo yum install -y jq docker-${DOCKER_VERSION}

sudo tee /etc/docker/daemon.json << EOF
{
    "log-driver": "journald",
    "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo service docker start
sudo docker info

# used by subsequent provision steps
sudo install -m 0777 -d /opt/configuration
