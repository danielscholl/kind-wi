#!/bin/sh

# Start Docker daemon
dockerd-entrypoint.sh &

# Wait for Docker daemon to start
until docker info >/dev/null 2>&1; do
  sleep 1
done

# Wait for OIDC provider to be ready
until curl -s "${SERVICE_ACCOUNT_ISSUER}.well-known/openid-configuration" >/dev/null 2>&1; do
  echo "Waiting for OIDC provider at ${SERVICE_ACCOUNT_ISSUER}"
  sleep 2
done

# Create kind configuration file
cat <<EOF > /kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /keys/sa.pub
      containerPath: /etc/kubernetes/pki/sa.pub
    - hostPath: /keys/sa.key
      containerPath: /etc/kubernetes/pki/sa.key
  kubeadmConfigPatches:
  - |
    apiVersion: kubeadm.k8s.io/v1beta3
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        service-account-issuer: "${SERVICE_ACCOUNT_ISSUER}"
        service-account-key-file: /etc/kubernetes/pki/sa.pub
        service-account-signing-key-file: /etc/kubernetes/pki/sa.key
    controllerManager:
      extraArgs:
        service-account-private-key-file: /etc/kubernetes/pki/sa.key
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
EOF

# Create the kind cluster
kind create cluster --name azure-workload-identity --config=/kind-config.yaml --image=kindest/node:v1.31.1

# Export kubeconfig
kind get kubeconfig --name azure-workload-identity > /kubeconfig/config 

# Update kubeconfig to use localhost instead of 0.0.0.0
sed -i 's/0.0.0.0/localhost/g' /kubeconfig/config

# Ensure the correct port is set in the kubeconfig
sed -i 's/:[0-9]\+/:6443/g' /kubeconfig/config

# Test cluster access
kubectl --kubeconfig=/kubeconfig/config get nodes

# Keep the container running
tail -f /dev/null
