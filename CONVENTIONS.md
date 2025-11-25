# Coding and Infrastructure Conventions

These conventions apply to all application code, infrastructure code, containers, and Kubernetes resources in this repository.

---

## 1. Preferred Languages and Versions

### Backend Services
- Node.js 20 LTS  
- Python 3.12  

Structure for each backend service:
- src/ for code
- tests/ for unit tests
- Dockerfile in project root

### Frontend
- Next.js (TypeScript, compatible with Node 20)

### Infrastructure
- Terraform version 1.8 or later
- Helm v3
- Kubernetes API compatibility: 1.29

---

## 2. Container Base Images

General rules:
- Use only official minimal images.
- Avoid heavy OS bases unless required.
- All containers must run as non-root unless technically impossible.
- Multi-stage builds are mandatory.

Approved base images:
- Node: node:20-slim
- Python: python:3.12-slim
- Next.js builder: node:20-slim
- Next.js static export (in later phase): nginx:stable-alpine
- Avoid Alpine for Python services due to libc/musl issues.

---

## 3. Naming Conventions

### Azure Resource Naming

Format:
trench-<service>-<resource>-<env>

Where:
- trench: global project prefix
- service: logical component (aks, kv, sb, pg, vnet, acr, etc.)
- resource: Azure resource type (cluster, flex, core, etc.)
- env: dev, test, prod

Examples:
- trench-aks-cluster-dev
- trench-kv-core-dev
- trench-sb-core-dev
- trench-pg-flex-dev
- trench-vnet-hub-dev
- trench-vnet-spoke-dev

---

### Kubernetes Resource Naming

Format:
<app>-<component>

Examples:
- api-gateway-deployment
- events-api-service
- ui-frontend-deployment

Namespaces:
- infra → for platform add-ons
- apps → for workloads
- argocd → for ArgoCD itself

---

### GitHub Workflow Naming

Format:
ci-<service>.yaml  
build-<service>.yaml  
scan-<service>.yaml

Examples:
- ci-service-a.yaml
- build-ui.yaml
- scan-service-b.yaml

---

## 4. Azure Tagging Strategy

All Azure resources must include these tags:

owner: the responsible person  
environment: dev, test, or prod  
cost-center: logical grouping for cost tracking  
purpose: short description of what the resource does  

Example tag set:
owner = "adrian"
environment = "dev"
cost-center = "aks-lab"
purpose = "postgres-flex-server"

Tags are mandatory across all Terraform modules.

---

## 5. Environment Markers

Valid environment suffixes:
dev  
test  
prod  

Temporary environments must be prefixed (for example adrian-dev) and removed when no longer needed.

