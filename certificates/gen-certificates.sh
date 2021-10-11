#!/bin/bash
CFG_PATH=$(pwd)/configuration

# CA certificate and private key
cfssl gencert -initca "${CFG_PATH}/ca-csr.json" | cfssljson -bare ca

# admin client certificate and private key
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -profile=kubernetes \
  "${CFG_PATH}/admin-csr.json" \
| cfssljson -bare admin

# kubelet client certificates
for worker in worker-0 worker-1 worker-2; do
  PUBLIC_IP=$(
    aws ec2 describe-instances \
      --filters Name=instance-state-name,Values=running \
                Name=tag:Name,Values="${worker}" \
      --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
      --output text
  )

  PRIVATE_IP=$(
    aws ec2 describe-instances \
      --filters Name=instance-state-name,Values=running \
                Name=tag:Name,Values="${worker}" \
      --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
      --output text
  )

  if [ -n "${PUBLIC_IP}" ] && [ -n "${PRIVATE_IP}" ]; then
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config="${CFG_PATH}/ca-config.json" \
      -hostname="${worker},${PUBLIC_IP},${PRIVATE_IP}" \
      -profile=kubernetes \
      "${CFG_PATH}/${worker}-csr.json" \
    | cfssljson -bare ${worker}
  fi
done

# controller manager client certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -profile=kubernetes \
  "${CFG_PATH}/kube-controller-manager-csr.json" \
| cfssljson -bare kube-controller-manager

# kube-proxy client certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -profile=kubernetes \
  "${CFG_PATH}/kube-proxy-csr.json" \
| cfssljson -bare kube-proxy

# kube-scheduler client certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -profile=kubernetes \
  "${CFG_PATH}/kube-scheduler-csr.json" \
| cfssljson -bare kube-scheduler

# kubernetes API server certificate
KUBERNETES_PUBLIC_DNS=$(
  aws elbv2 describe-load-balancers \
    --name k8s-external \
    --query 'LoadBalancers[*].[DNSName]' \
    --output text
)

KUBERNETES_PRIVATE_DNS=$(
  aws elbv2 describe-load-balancers \
    --name k8s-internal \
    --query 'LoadBalancers[*].[DNSName]' \
    --output text
)

KUBERNETES_HOSTNAMES=(
  10.32.0.1
  10.240.0.10
  10.240.0.11
  10.240.0.12
  "${KUBERNETES_PUBLIC_DNS}"
  "${KUBERNETES_PRIVATE_DNS}"
  127.0.0.1
  kubernetes
  kubernetes.default
  kubernetes.default.svc
  kubernetes.default.svc.cluster
  kubernetes.svc.cluster.local
)
KUBERNETES_CSR_HOSTNAMES=$(IFS=, ; echo "${KUBERNETES_HOSTNAMES[*]}")
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -hostname="${KUBERNETES_CSR_HOSTNAMES}" \
  -profile=kubernetes \
  "${CFG_PATH}/kubernetes-csr.json" \
| cfssljson -bare kubernetes

# service account certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config="${CFG_PATH}/ca-config.json" \
  -profile=kubernetes \
  "${CFG_PATH}/service-account-csr.json" | cfssljson -bare service-account

# distribute the worker certificates
WORKER_INSTANCE_IDS=$(
  aws ec2 describe-instances \
    --filters Name=tag:Role,Values=worker \
              Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId]' \
    --out text
)

i=0
for instance in ${WORKER_INSTANCE_IDS}; do
    scp ca.pem "worker-${i}.pem" "worker-${i}-key.pem" "ec2-user@${instance}":~/
    : $((i+=1))
done

# distribute the controller certificates
CONTROLLER_INSTANCE_IDS=$(
  aws ec2 describe-instances \
    --filters Name=tag:Role,Values=controller \
              Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].[InstanceId]' \
    --out text
)

for instance in ${CONTROLLER_INSTANCE_IDS}; do
    scp \
      ca.pem ca-key.pem \
      kubernetes.pem kubernetes-key.pem \
      service-account.pem service-account-key.pem \
      "ec2-user@${instance}":~/
done