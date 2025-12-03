#!/usr/bin/env bash
set -euo pipefail

# Helper to bootstrap Phase 3.1 and 3.2 on the dev cluster:
# - 3.1: internal NGINX Ingress
# - 3.2: kube-prometheus-stack (Prometheus + Grafana)
# Run this after SSH-ing into the jump box and cloning the repo.

RESOURCE_GROUP="rg-trench-aks-dev"
CLUSTER_NAME="trench-aks-cluster-dev"
OBS_NAMESPACE="observability"
PROM_RELEASE="kube-prometheus-stack"
PROM_CHART="prometheus-community/kube-prometheus-stack"

main() {
  echo "[1/5] Getting AKS credentials for $CLUSTER_NAME in $RESOURCE_GROUP..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  echo "[2/5] Applying infra Kustomize overlay (infra-ingress namespace)..."
  kubectl apply -k k8s/overlays/dev/infra

  echo "[3/5] Installing or upgrading NGINX Ingress via Helm..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace infra-ingress \
    --values k8s/infra/helm/ingress-nginx-values.yaml

  echo "[4/5] Installing or upgrading $PROM_RELEASE (Prometheus + Grafana) via Helm..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install "$PROM_RELEASE" "$PROM_CHART" \
    --namespace "$OBS_NAMESPACE" \
    --create-namespace \
    --values k8s/infra/helm/kube-prometheus-stack-values.yaml

  echo "[5/5] Verifying core pods and services..."
  kubectl get pods -n infra-ingress
  kubectl get svc  -n infra-ingress
  kubectl get pods -n "$OBS_NAMESPACE"
  kubectl get svc  -n "$OBS_NAMESPACE"

  echo "\nPhase 3.1 and 3.2 deployment complete."
  echo "- NGINX Ingress running in namespace: infra-ingress"
  echo "- Prometheus/Grafana running in namespace: $OBS_NAMESPACE"
}

main "$@"
