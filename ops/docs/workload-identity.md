# Workload Identity Architecture

This document describes how AKS workloads authenticate to Azure services using Entra Workload Identity.

## Overview

Workload Identity eliminates the need for static credentials (connection strings, API keys) by allowing Kubernetes pods to authenticate directly to Azure using federated identity tokens.

## Identity Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Pod                                                                     ││
│  │  ├─ ServiceAccount: catalog-api                                         ││
│  │  │   └─ annotation: azure.workload.identity/client-id: <client-id>      ││
│  │  │                                                                      ││
│  │  └─ Projected Token Volume                                              ││
│  │      └─ /var/run/secrets/azure/tokens/azure-identity-token              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                      │                                      │
│                                      │ OIDC Token                           │
│                                      ▼                                      │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       │ Token Exchange
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Microsoft Entra ID                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ User Assigned Managed Identity                                           ││
│  │  ├─ Name: trench-aks-cluster-dev-catalog-api                             ││
│  │  ├─ Client ID: <guid>                                                    ││
│  │  │                                                                       ││
│  │  └─ Federated Identity Credential                                        ││
│  │      ├─ Issuer: https://<region>.oic.prod-aks.azure.com/<tenant>/<oidc>  ││
│  │      ├─ Subject: system:serviceaccount:tinyshop:catalog-api              ││
│  │      └─ Audience: api://AzureADTokenExchange                             ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                      │                                       │
│                                      │ Azure AD Token                        │
│                                      ▼                                       │
└──────────────────────────────────────┼───────────────────────────────────────┘
                                       │
                                       │ RBAC Authorization
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure Resources                                │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐           │
│  │    Key Vault     │  │   Service Bus    │  │     Postgres     │           │
│  │                  │  │                  │  │                  │           │
│  │ Role Assignment: │  │ Role Assignment: │  │ AAD Auth or      │           │
│  │ Key Vault        │  │ Data Sender/     │  │ Connection via   │           │
│  │ Secrets User     │  │ Data Receiver    │  │ Managed Identity │           │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. User Assigned Managed Identity

Each workload has its own identity in Entra ID:

| Workload | Identity Name | Purpose |
|----------|---------------|---------|
| catalog-api | `trench-aks-cluster-dev-catalog-api` | Product catalog service |
| orders-api | `trench-aks-cluster-dev-orders-api` | Order management service |
| order-worker | `trench-aks-cluster-dev-order-worker` | Background order processor |

### 2. Federated Identity Credential

Links the Kubernetes ServiceAccount to the Managed Identity:

- **Issuer**: AKS OIDC issuer URL (unique per cluster)
- **Subject**: `system:serviceaccount:<namespace>:<serviceaccount-name>`
- **Audience**: `api://AzureADTokenExchange`

### 3. Kubernetes ServiceAccount

Each pod uses a ServiceAccount with the workload identity annotation:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog-api
  namespace: tinyshop
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
  labels:
    azure.workload.identity/use: "true"
```

### 4. Pod Configuration

Pods must:
1. Use the annotated ServiceAccount
2. Have the workload identity label

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: catalog-api
  namespace: tinyshop
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: catalog-api
  containers:
    - name: catalog-api
      image: trenchacrcoredev.azurecr.io/catalog-api:latest
```

## RBAC Role Assignments

### Key Vault

All workloads have `Key Vault Secrets User` role:
- Get secrets
- List secrets

### Service Bus

| Workload | Role | Scope |
|----------|------|-------|
| orders-api | Azure Service Bus Data Sender | orders queue |
| order-worker | Azure Service Bus Data Receiver | orders queue |

### Postgres

Postgres Flexible Server supports Entra authentication. Options:
1. **AAD Admin**: Configure the managed identity as an AAD admin
2. **AAD User**: Create database users mapped to managed identities

For this lab, we use password authentication stored in Key Vault. AAD integration for Postgres can be added in Phase 8 as an advanced topic.

## SDK Usage

### Node.js (catalog-api, order-worker)

```typescript
import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";

// DefaultAzureCredential automatically uses workload identity in AKS
const credential = new DefaultAzureCredential();
const client = new SecretClient("https://trench-kv-core-dev.vault.azure.net/", credential);

const secret = await client.getSecret("postgres-password");
```

### Python (orders-api)

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# DefaultAzureCredential automatically uses workload identity in AKS
credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://trench-kv-core-dev.vault.azure.net/", credential=credential)

secret = client.get_secret("postgres-password")
```

## Terraform Outputs

After `terraform apply`, retrieve the client IDs for ServiceAccount annotations:

```bash
terraform output workload_identity_client_ids
```

Output:
```hcl
{
  "catalog_api"  = "<guid>"
  "orders_api"   = "<guid>"
  "order_worker" = "<guid>"
}
```

## Troubleshooting

### Token not projected

Verify the pod has:
- `azure.workload.identity/use: "true"` label
- ServiceAccount with `azure.workload.identity/client-id` annotation

### 401 Unauthorized from Azure

Check:
1. Federated credential subject matches `system:serviceaccount:<namespace>:<sa-name>`
2. RBAC role assignment exists for the managed identity
3. Issuer URL matches the AKS OIDC issuer

### View projected token

```bash
kubectl exec -it <pod> -- cat /var/run/secrets/azure/tokens/azure-identity-token
```

Decode the JWT to verify claims:
```bash
kubectl exec -it <pod> -- cat /var/run/secrets/azure/tokens/azure-identity-token | cut -d. -f2 | base64 -d | jq
```
