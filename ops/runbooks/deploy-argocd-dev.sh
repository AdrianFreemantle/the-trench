#!/usr/bin/env bash
set -euo pipefail

# Helper to install ArgoCD on the dev cluster (Phase 5.2)
# Run this after SSH-ing into the jump box and cloning the repo.

RESOURCE_GROUP="rg-trench-aks-dev"
CLUSTER_NAME="trench-aks-cluster-dev"
ARGOCD_NAMESPACE="argocd"
ARGOCD_RELEASE="argocd"
ARGOCD_CHART="argo/argo-cd"

main() {
  echo "[1/4] Getting AKS credentials for $CLUSTER_NAME in $RESOURCE_GROUP..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  echo "[2/4] Applying ArgoCD namespace and ingress via Kustomize..."
  kubectl apply -k k8s/overlays/dev/infra

  echo "[3/4] Adding ArgoCD Helm repo..."
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  echo "[4/4] Installing or upgrading ArgoCD via Helm..."
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART" \
    --namespace "$ARGOCD_NAMESPACE" \
    --values k8s/infra/helm/argocd-values.yaml

  echo ""
  echo "✅ ArgoCD installation complete!"
  echo ""
  echo "To retrieve the admin password:"
  echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  echo ""
  echo "To access ArgoCD UI:"
  echo "  1. Get the Ingress IP: kubectl get svc -n infra-ingress ingress-nginx-controller"
  echo "  2. Add to /etc/hosts: <INGRESS_IP> argocd.trench.internal"
  echo "  3. Open browser: http://argocd.trench.internal"
  echo "  4. Login with username 'admin' and the password from above"
  echo ""
}

main "$@"
