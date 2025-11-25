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

---

## 6. Secrets and Security Hygiene

### Secret Storage
- **Never** store sensitive values in Git, Kubernetes Secrets, or container images.
- All long-lived secrets live in Azure Key Vault and are mounted via CSI or retrieved through the SDK with Workload Identity.
- Short-lived local secrets belong in `.env.local` files that are ignored by Git. Provide `*.example` files when documentation is needed.

### Access Patterns
- Every workload that needs Azure access must use a dedicated Entra Workload Identity with least-privilege role assignments.
- Kubernetes ServiceAccounts must be clearly mapped to their federated credentials and named `<app>-<purpose>-sa` to simplify audits.
- Key Vault access policies/role assignments are managed through Terraform; manual portal edits are not allowed.

### Handling of Credentials
- Rotate secrets when moving between phases or after demos. Track rotation cadence in runbooks under `ops/runbooks`.
- Never paste secrets into PRs, issues, or ADRs. Reference them indirectly (e.g., "Key Vault secret `trench-sb-conn-prod`") instead.
- Use sealed terminals or password managers when sharing one-off secrets with collaborators.

### Local Development Hygiene
- Use `az login` + Workload Identity emulation where possible. Avoid storing Azure service principals locally.
- Clear `.env` files and Docker volumes before recording demos or sharing screenshots.
- Ensure unit/integration tests do not rely on real secrets; inject fake values or use mocks.

### Supply Chain Guardrails
- Container images must be scanned (Trivy or equivalent) before publishing to ACR.
- Pin Docker base images to digests in production manifests once workloads stabilize.
- Review dependency updates for known CVEs and document mitigations when accepting temporary risk.

