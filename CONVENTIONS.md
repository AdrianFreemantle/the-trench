# Coding and Infrastructure Conventions

This file defines the minimal conventions required for consistent application code, containers, Azure resources, Terraform modules, and Kubernetes manifests.

---

# 1. Languages and Versions
- Node.js 20 LTS  
- Python 3.12  
- Next.js (TypeScript)  
- Terraform 1.8+  
- Helm v3  
- Kubernetes 1.29  

---

# 2. Container Base Images
- Use official minimal images only  
- Multi stage builds are required  
- Containers must run as non root  
- Avoid Alpine for Python  

Approved bases:
- node:20-slim  
- python:3.12-slim  
- nginx:stable-alpine (Next.js static export)

---

# 3. Azure Naming

Global format:
```
trench-<service-group>-<component>-<env>
```

Service groups:
aks, vnet, fw, acr, kv, pg, sb, dns, pe

Resource Groups:
```
rg-trench-<group>-<env>
```
Groups: core, data, aks

Examples:
- trench-aks-cluster-dev  
- trench-vnet-hub-dev  
- trench-vnet-spoke-dev  
- trench-acr-core-dev  
- trench-kv-core-dev  
- trench-pg-flex-dev  
- trench-sb-core-dev  
- trench-pe-kv-dev  
- rg-trench-core-dev  

---

# 4. Kubernetes Naming

Workloads:
```
<app>-<component>
```

Examples:
- orders-api-deployment  
- events-worker-deployment  
- ui-frontend-service  

Namespaces:
- infra  
- apps  
- argocd  

ServiceAccounts for Workload Identity:
```
<app>-<purpose>-sa>
```

---

# 5. Azure Tags

Applied to every resource:
- owner  
- environment  
- cost-center  
- purpose  

Example:
```
owner = "adrian"
environment = "dev"
cost-center = "aks-lab"
purpose = "postgres-flex"
```

---

# 6. Secrets and Security

- Never store sensitive values in Git  
- Never use Kubernetes Secrets for sensitive values  
- All long lived secrets live in Azure Key Vault  
- Workload Identity is mandatory for Azure access  
- CSI driver is the default secret injection method  
- No manual Key Vault access policy edits; Terraform only  