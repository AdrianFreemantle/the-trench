#!/usr/bin/env bash
set -euo pipefail

# Simple helper to bootstrap Phase 3.1 (internal NGINX Ingress) on the dev cluster
# from the jump host. Run this after SSH-ing into the jump box and cloning the repo.

# You can optionally export SUBSCRIPTION_ID before running this script to avoid editing it.
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-<REPLACE_WITH_SUBSCRIPTION_ID>}"

RESOURCE_GROUP="rg-trench-aks-dev"
CLUSTER_NAME="trench-aks-cluster-dev"

main() {
  echo "[1/5] az login (device code) if not already logged in..."
  # This is safe to re-run; if already logged in it will just refresh context.
  az login --use-device-code >/dev/null 2>&1 || true

  if [ "$SUBSCRIPTION_ID" != "<REPLACE_WITH_SUBSCRIPTION_ID>" ]; then
    echo "[2/5] Setting Azure subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
  else
    echo "[2/5] SUBSCRIPTION_ID is still <REPLACE_WITH_SUBSCRIPTION_ID>.\n" \
         "       Export SUBSCRIPTION_ID or edit this script to set it explicitly.\n" \
         "       Continuing with whatever default subscription az is using..."
  fi

  echo "[3/5] Getting AKS credentials for $CLUSTER_NAME in $RESOURCE_GROUP..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  echo "[4/5] Applying infra Kustomize overlay (infra-ingress namespace)..."
  kubectl apply -k k8s/overlays/dev/infra

  echo "[5/5] Installing or upgrading NGINX Ingress via Helm..."
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
