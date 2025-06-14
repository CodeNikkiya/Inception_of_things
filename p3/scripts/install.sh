#!/bin/bash

set -e

# Install Docker

if command -v docker &> /dev/null; then
  echo "✅ Docker is already installed. Skipping..."
else
  echo "=== Installing Docker ==="
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker $USER
  echo "Please log out and log back in to apply Docker group changes."
fi

# Install K3D

if command -v k3d &> /dev/null; then
  echo "✅ k3d is already installed. Skipping..."
else
  echo "=== Installing k3d ==="
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# Install kubectl

if command -v kubectl &> /dev/null; then
  echo "✅ kubectl is already installed. Skipping..."
else
  echo "=== Installing kubectl ==="
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  echo "Latest kubectl version: $KUBECTL_VERSION"

  if [ -n "$KUBECTL_VERSION" ]; then
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    echo "✅ kubectl installed successfully!"
  else
    echo "❌ Failed to fetch latest kubectl version. Check your internet/DNS."
    exit 1
  fi
fi

# Create k3d cluster

if k3d cluster list | grep -q "^mycluster\s"; then
  echo "✅ Cluster 'mycluster' already exists. Skipping creation."
else
  k3d cluster create mycluster --api-port 6550 -p "8888:80@loadbalancer"
fi

# Ensure 'argocd' namespace exists and wait for it to be ready

if kubectl get namespace argocd &> /dev/null; then
  echo "✅ Argo CD namespace already exists."
else
  echo "=== Creating 'argocd' namespace ==="
  kubectl create namespace argocd
  echo "Waiting for 'argocd' namespace to be established..."
  kubectl wait --for=condition=Established namespace/argocd --timeout=90s
fi

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Setup complete ==="
echo "To access Argo CD UI in the machine running the cluster:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo
echo "Then visit: http://localhost:8080"
echo "Get admin password with:"
echo '  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
echo "To access in the host machine running the vm that is running the cluster:"
echo "ssh -L 8080:localhost:8080 user@192.168.56.110"

