#!/usr/bin/env bash
set -euo pipefail

ETCD_VERSION="v3.5.0"
ETCD_SHA256SUM="864baa0437f8368e0713d44b83afe21dce1fb4ee7dae4ca0f9dd5f0df22d01c4"
ETCD_EXTRACT_DIR="/src/etcd-${ETCD_VERSION}-linux-amd64"
ETCD_FILE="etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
ETCD_FILE_PATH="/src/${ETCD_FILE}"

sudo mkdir -p "${ETCD_EXTRACT_DIR}"
sudo curl -sL https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/${ETCD_FILE} \
     -o ${ETCD_FILE_PATH}

echo "${ETCD_SHA256SUM} ${ETCD_FILE_PATH}" | sha256sum -c -

sudo tar --strip-components=1 -zxvf ${ETCD_FILE_PATH} -C ${ETCD_EXTRACT_DIR}

for bin in etcd etcdctl etcdutl; do
  sudo ln -sv ${ETCD_EXTRACT_DIR}/${bin} /usr/local/bin/${bin}
done

sudo install -m 0700 -d /var/lib/etcd
sudo install -m 0755 -d /etc/etcd

for cert in ca.pem kubernetes-key.pem kubernetes.pem; do
  sudo install -m 0644 /opt/configuration/${cert} /etc/etcd/${cert}
done

sudo install -m 0644 /opt/configuration/etcd/etcd.service \
                     /etc/systemd/system/etcd.service

sudo pip3 install j2cli

sudo tee /etc/cloud/cloud.cfg.d/etcd-bootstrap.cfg << EOF
#cloud-config
runcmd:
  - j2 /etc/systemd/system/etcd.service /run/cloud-init/instance-data.json -o /etc/systemd/system/etcd.service
  - systemctl daemon-reload
  - systemctl enable etcd
  - systemctl start --no-block etcd
EOF
