#!/bin/bash
set -euo pipefail

# Install k3s — runs as EC2 user data on first boot
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
until kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes 2>/dev/null | grep -q " Ready"; do
  sleep 5
done

echo "k3s is ready"
