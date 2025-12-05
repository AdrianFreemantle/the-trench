#!/usr/bin/env bash

# Configure kubectl for the dev AKS cluster and print basic cluster information.
#
# Steps:
# - Optionally set the Azure subscription (if SUBSCRIPTION_ID is provided).
# - Retrieve credentials for trench-aks-cluster-dev into the current kubeconfig.
# - Show current kubectl context and node labels.
# - Run the detailed AKS checks in check-aks-dev.sh (if present and executable).
#
# Defaults:
# - RG_NAME defaults to rg-trench-aks-dev (override via env var RG_NAME).
# - AKS_NAME defaults to trench-aks-cluster-dev (override via env var AKS_NAME).
# - SUBSCRIPTION_ID is optional; if set, az account set will be called.
#
# Prerequisites on the jump host:
# - az login --use-device-code (or equivalent) has already been run.
# - Azure CLI and kubectl are installed.

set -euo pipefail

RG_NAME_DEFAULT="rg-trench-aks-dev"
AKS_NAME_DEFAULT="trench-aks-cluster-dev"

RG_NAME="${RG_NAME:-$RG_NAME_DEFAULT}"
AKS_NAME="${AKS_NAME:-$AKS_NAME_DEFAULT}"

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}" || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Configuring kubectl context for AKS cluster =="
echo "Resource group : $RG_NAME"
echo "Cluster name   : $AKS_NAME"

if [ -n "$SUBSCRIPTION_ID" ]; then
  echo "Setting Azure subscription to $SUBSCRIPTION_ID"
  az account set --subscription "$SUBSCRIPTION_ID"
fi

echo
echo "Retrieving AKS credentials..."
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$AKS_NAME" \
  --overwrite-existing

echo
echo "== kubectl context and nodes =="
kubectl config current-context || true
kubectl get nodes --show-labels || true

echo
echo "== AKS basic info =="
az aks show \
  --resource-group "$RG_NAME" \
  --name "$AKS_NAME" \
  --query '{name:name, kubernetesVersion:kubernetesVersion, location:location, nodeResourceGroup:nodeResourceGroup}' \
  -o json

echo
echo "== Node pools (table) =="
az aks nodepool list \
  --resource-group "$RG_NAME" \
  --cluster-name "$AKS_NAME" \
  -o table

echo
echo "== Autoscaler settings for apps and platform node pools =="
for pool in apps platform; do
  echo "-- $pool --"

  if ! az aks nodepool show \
    --resource-group "$RG_NAME" \
    --cluster-name "$AKS_NAME" \
    --name "$pool" \
    >/dev/null 2>&1; then
    echo "Node pool '$pool' not found in cluster $AKS_NAME."
    echo
    continue
  fi

  enabled=$(az aks nodepool show \
    --resource-group "$RG_NAME" \
    --cluster-name "$AKS_NAME" \
    --name "$pool" \
    --query "enableAutoScaling" \
    -o tsv)

  min=$(az aks nodepool show \
    --resource-group "$RG_NAME" \
    --cluster-name "$AKS_NAME" \
    --name "$pool" \
    --query "minCount" \
    -o tsv)

  max=$(az aks nodepool show \
    --resource-group "$RG_NAME" \
    --cluster-name "$AKS_NAME" \
    --name "$pool" \
    --query "maxCount" \
    -o tsv)

  count=$(az aks nodepool show \
    --resource-group "$RG_NAME" \
    --cluster-name "$AKS_NAME" \
    --name "$pool" \
    --query "count" \
    -o tsv)

  echo "enableAutoScaling: $enabled"
  echo "minCount:          $min"
  echo "maxCount:          $max"
  echo "current count:     $count"

  if [ "$enabled" = "true" ] && [ "$min" = "1" ] && [ "$max" = "2" ]; then
    echo "STATUS: OK (autoscaler configured for 1–2 nodes)"
  else
    echo "STATUS: WARN (autoscaler not configured as expected)"
  fi

  echo
done

echo "== Kubernetes nodes (detailed) =="
kubectl get nodes -o wide || true

echo
echo "== Sample pods (first 40 across all namespaces) =="
kubectl get pods -A -o wide | head -n 40 || true
