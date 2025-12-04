#!/usr/bin/env bash
set -euo pipefail

# Helper to bootstrap Phase 3.1, 3.2, and 3.3 on the dev cluster:
# - 3.1: internal NGINX Ingress
# - 3.2: kube-prometheus-stack (Prometheus + Grafana)
# - 3.3: OpenTelemetry Collector
# Run this after SSH-ing into the jump box and cloning the repo.

RESOURCE_GROUP="rg-trench-aks-dev"
CLUSTER_NAME="trench-aks-cluster-dev"
OBS_NAMESPACE="observability"
OTEL_NAMESPACE="otel-system"
PROM_RELEASE="kube-prometheus-stack"
PROM_CHART="prometheus-community/kube-prometheus-stack"
OTEL_RELEASE="opentelemetry-collector"
OTEL_CHART="open-telemetry/opentelemetry-collector"
JAEGER_RELEASE="jaeger"
JAEGER_CHART="jaegertracing/jaeger"

main() {
  echo "[1/9] Getting AKS credentials for $CLUSTER_NAME in $RESOURCE_GROUP..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

  echo "[2/9] Applying infra Kustomize overlay (namespaces and ingress)..."
  kubectl apply -k k8s/overlays/dev/infra

  echo "[3/9] Installing or upgrading NGINX Ingress via Helm..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace infra-ingress \
    --values k8s/infra/helm/ingress-nginx-values.yaml

  echo "[4/9] Installing or upgrading $PROM_RELEASE (Prometheus + Grafana) via Helm..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install "$PROM_RELEASE" "$PROM_CHART" \
    --namespace "$OBS_NAMESPACE" \
    --create-namespace \
    --values k8s/infra/helm/kube-prometheus-stack-values.yaml

  echo "[5/9] Installing or upgrading $JAEGER_RELEASE (Jaeger) via Helm..."
  helm repo add jaegertracing https://jaegertracing.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install "$JAEGER_RELEASE" "$JAEGER_CHART" \
    --namespace "$OBS_NAMESPACE" \
    --values k8s/infra/helm/jaeger-values.yaml

  echo "[6/9] Installing or upgrading $OTEL_RELEASE (OpenTelemetry Collector) via Helm..."
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install "$OTEL_RELEASE" "$OTEL_CHART" \
    --namespace "$OTEL_NAMESPACE" \
    --create-namespace \
    --values k8s/infra/helm/opentelemetry-collector-values.yaml

  echo "[7/9] Waiting for Jaeger to be ready..."
  kubectl rollout status deployment/"$JAEGER_RELEASE" -n "$OBS_NAMESPACE" --timeout=120s

  echo "[8/9] Waiting for OTEL Collector to be ready..."
  kubectl rollout status deployment/"$OTEL_RELEASE" -n "$OTEL_NAMESPACE" --timeout=120s

  echo "[9/9] Verifying core pods and services..."
  kubectl get pods -n infra-ingress
  kubectl get svc  -n infra-ingress
  kubectl get pods -n "$OBS_NAMESPACE"
  kubectl get svc  -n "$OBS_NAMESPACE"
  kubectl get pods -n "$OTEL_NAMESPACE"
  kubectl get svc  -n "$OTEL_NAMESPACE"

  echo "\nPhase 3.1, 3.2, and 3.3 deployment complete."
  echo "- NGINX Ingress running in namespace: infra-ingress"
  echo "- Prometheus/Grafana running in namespace: $OBS_NAMESPACE"
  echo "- Jaeger running in namespace: $OBS_NAMESPACE"
  echo "- OpenTelemetry Collector running in namespace: $OTEL_NAMESPACE"
}

main "$@"
