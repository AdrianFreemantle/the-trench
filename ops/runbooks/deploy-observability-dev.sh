#!/usr/bin/env bash
set -euo pipefail

# Simple helper to bootstrap Phase 3.1 (internal NGINX Ingress) on the dev cluster
# from the jump host. Run this after SSH-ing into the jump box and cloning the repo.

RESOURCE_GROUP="rg-trench-aks-dev"
CLUSTER_NAME="trench-aks-cluster-dev"

main() {
  echo "[1/3] Getting AKS credentials for $CLUSTER_NAME in $RESOURCE_GROUP..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  echo "[2/3] Applying infra Kustomize overlay (infra-ingress namespace)..."
  kubectl apply -k k8s/overlays/dev/infra

  echo "[3/3] Installing or upgrading NGINX Ingress via Helm..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace infra-ingress \
    --values k8s/infra/ingress-nginx-values.yaml

  echo "\nDone. Verify with:"
  echo "  kubectl get pods -n infra-ingress"
  echo "  kubectl get svc  -n infra-ingress"
}

main "$@"
