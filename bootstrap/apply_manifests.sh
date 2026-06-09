#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl apply -f /home/ec2-user/k8s/namespace.yaml
kubectl apply -f /home/ec2-user/k8s/serviceaccount.yaml
kubectl apply -f /home/ec2-user/k8s/role.yaml
kubectl apply -f /home/ec2-user/k8s/rolebinding.yaml
kubectl apply -f /home/ec2-user/k8s/deployment.yaml
kubectl apply -f /home/ec2-user/k8s/network_policy.yaml

kubectl -n dev rollout status deployment/nginx
kubectl -n dev get pods
