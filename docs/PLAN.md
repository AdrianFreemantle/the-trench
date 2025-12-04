# Plan


## Phase 0: Repo, Structure, and Working Agreements

## Phase 0: Repository Setup, Conventions, and App Skeletons
Establish the repository structure, conventions, governance, and minimal service skeletons needed for later infrastructure and CI/CD work.  
No real business logic yet. Only “hello world” containers to ensure everything builds and runs.

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 0.1 Terraform & Repo Setup

---

## Phase 1: Core Azure Infrastructure with Terraform

**Goal:** Provision the foundational Azure environment with Terraform: hub–spoke VNets, Firewall, ACR, private AKS, Key Vault, Postgres Flexible, Service Bus, and Private Endpoints.  
Execution is **manual `terraform apply`** for now; infra Terraform automation is introduced in **Phase 7.5**.

---

### 1.1 Terraform Bootstrap

Create and initialize `infra/terraform/`:

- Files:
  - `providers.tf`
  - `backend.tf` (local state for Phase 1; remote backend migration is handled in **Phase 8.10**)
  - `main.tf`
  - `variables.tf`
  - `outputs.tf`

- Actions:
  - Configure Azure provider authentication (via `az login`).
  - Define:
    - `var.environment` (start with `"dev"`).
    - `locals` for naming and tagging (using `trench-<service>-<resource>-<env>` and the tag set from CONVENTIONS.md).

**Outcome:**
- You can run `terraform init` and `terraform plan` successfully.

---

### 1.2 Resource Groups and Tagging

Create at least these RGs:

- `rg-trench-core-dev`  
  ACR, Key Vault, Service Bus, Firewall, hub VNet.

- `rg-trench-data-dev`  
  Postgres Flexible + related Private Endpoint resources.

- `rg-trench-aks-dev`  
  AKS cluster + spoke VNet.

Apply consistent tags to every resource via Terraform:

- `owner`
- `environment`
- `cost-center`
- `purpose`

**Outcome:**
- Resource groups exist with consistent naming and tags.

---

### 1.3 Networking: Hub–Spoke VNets

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 1.1 VNet + Subnets

Provision hub and spoke VNets using Terraform.

**Hub VNet (core)**
- Address space (example): `10.0.0.0/16`
- Subnets:
  - `AzureFirewallSubnet`
  - `shared-services`

**Spoke VNet (aks)**
- Address space (example): `10.1.0.0/16`
- Subnets:
  - `aks-nodes`
  - `private-endpoints`

**Peering**
- Hub ↔ spoke VNet peering in both directions.
- Allow forwarded traffic where required.

**Outcome:**
- Baseline network topology in place for private AKS and Private Endpoints.

---

### 1.4 Azure Firewall (Minimal Initial Policy)

Deploy Azure Firewall into the hub VNet:

- Place firewall in `AzureFirewallSubnet`.
- Assign a single public IP for the firewall data plane.
  - Note: During implementation we hit the regional public IP quota in this subscription, which forced us to drop the separate management public IP from the initial design. Using only the data-plane IP is sufficient for this lab’s goals. In a less constrained environment you could reintroduce a dedicated management IP later for forced tunnelling or a more advanced management topology.
- Create a **minimal** rule set:
  - Network rules / application rules sufficient for:
    - AKS control plane connectivity.
    - Node pool image pulls from ACR / Microsoft endpoints.
  - Everything else denied by default.

Document that firewall rules are intentionally loose in Phase 1 and will be tightened in **Phase 2.4** (egress hardening via UDR and Azure Firewall).

**Outcome:**
- Egress from the AKS spoke will be forced through Firewall (once UDRs are configured in later phases).

---

### 1.5 Azure Container Registry (ACR)

Deploy ACR into `rg-trench-core-dev`:

- Basic SKU to control cost.
- Naming consistent with conventions (for example `trenchacrcoredev`).
- For Phase 1, keep ACR admin user enabled and public network access allowed for simplicity; in **Phase 7.6** you will disable the admin user and rely on federated credentials / role assignments only.

Do not yet wire AKS to ACR via Terraform; that comes in the AKS section.

**Outcome:**
- ACR exists and is ready to receive images from your GitHub-based CI later.

---

### 1.6 Private AKS Cluster

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 1.2 AKS Cluster Creation

Provision AKS in `rg-trench-aks-dev` with:

- Node resource group (auto or explicit).
- Attached to the spoke VNet `aks-nodes` subnet.
- API server private endpoint only (no public API).
- RBAC enabled.
- OIDC issuer enabled.
- Workload Identity enabled.
- Two node pools (design intent):
  - `system` pool (small SKU, system workloads only).
  - `user` pool (for app workloads later).

Note: Due to AKS restricted-SKU rules for very small VM sizes and the tight free-tier vCPU quota in this subscription, the initial implementation temporarily runs with a **single** `system` node pool only. The `user` pool Terraform resource is commented out and will be reintroduced in a later hardening phase once the subscription is upgraded and larger SKUs are available without hitting quota limits. Initial deployment uses a single node pool (cost-optimised). System/user node pool split will occur after core platform is functioning. Node pool split moved to later phase.

Also:

- Configure AKS to use the ACR created in 1.5 (either via `azurerm_kubernetes_cluster` `acr` integration or role assignment).

**Outcome:**
- A private AKS cluster exists and can pull images from ACR (once CI pushes them).
- `az aks get-credentials` works from a machine with network access via the admin access path you provision in **Phase 2.1** (for example, Bastion, VPN, or a jump host in the hub VNet).

---

### 1.7 Azure PaaS: Key Vault, Postgres Flexible, Service Bus

Provision the minimal PaaS set in Terraform.

**Key Vault (rg-trench-core-dev)**

- Standard SKU.
- Soft-delete enabled; purge protection disabled for dev.
- RBAC-only access (no Key Vault access policies).
- Public network access disabled; access via Private Endpoint only.
- Private Endpoint into `private-endpoints` subnet in the spoke VNet, in the same resource group as the vault.
- Network ACLs configured to allow:
  - Private Endpoint traffic
  - Trusted Azure services where required.

**PostgreSQL Flexible Server (rg-trench-data-dev)**

- Dev-grade Burstable compute (smallest viable size), with small storage and auto-grow enabled.
- Latest supported Postgres major version in the region.
- Private access only (no public endpoint).
- Private Endpoint into `private-endpoints` subnet, in the same resource group as the server.
- Single server hosting one database per service:
  - `catalog`
  - `orders`

**Service Bus (rg-trench-core-dev)**

- Standard tier Service Bus namespace.
- Messaging entities:
  - Single queue `orders` for `OrderPlaced` messages.
- Uses a public endpoint with network/firewall rules; no Private Endpoint (Standard tier does not support Private Link).
- Initially allow broad access for simplicity; in **Phase 2.5.2** you will tighten Service Bus network rules to allow only the Azure Firewall public IP (and any required admin IPs/VPN ranges).

**Outcome:**
- All core PaaS resources exist, but no identities, roles, or workloads use them yet.

---

### 1.8 Private DNS for PaaS / Private Endpoints

Configure Azure Private DNS zones and links for:

- Key Vault `privatelink.vaultcore.azure.net`
- Postgres Flexible `privatelink.postgres.database.azure.com`

Service Bus uses a public endpoint and does not require a Private DNS zone in this design.

Actions:

- Create Private DNS zones.
- Link them to:
  - Hub VNet
  - Spoke VNet

Terraform should create DNS A records for each Private Endpoint.

**Outcome:**
- Name resolution for all Private Endpoints works from the AKS spoke VNet.

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 4.1 Terraform PaaS Provisioning

---

### 1.9 Checkpoint

By the end of Phase 1:

- `terraform apply` successfully creates:
  - `rg-trench-core-dev`, `rg-trench-data-dev`, `rg-trench-aks-dev`
  - Hub and spoke VNets with peering
  - Azure Firewall in hub
  - ACR
  - Private AKS cluster (no add-ons)
  - Key Vault (with Private Endpoint)
  - Postgres Flexible (with Private Endpoint)
  - Service Bus namespace + `OrderPlaced` entity (Standard tier, public endpoint)
  - Private DNS zones and links for Key Vault and Postgres

You **do not** yet:

- Install ArgoCD, ingress controllers, CSI drivers, Prometheus/Grafana, or any app workloads.
- Automate Terraform via CI/CD.

Those belong in **Phase 2** (cluster add-ons + identity plumbing) and later phases.

---

## Phase 2: Cluster Add-ons and Security Plumbing

**Goal:** Install core cluster add-ons and wire Workload Identity and Key Vault CSI.

Steps:

2.1 Cluster access:
- Provision a small Linux jump-host VM in the hub VNet:
  - Use a small, cost-conscious SKU (for example `Standard_B1s` or `Standard_B2s`).
  - Restrict SSH access via NSG rules to your trusted admin IP ranges.
  - Use cloud-init to install Azure CLI and `kubectl` so the VM is ready for cluster admin tasks after `terraform apply`.
- Configure kubectl access via:
  - SSH into the jump-host VM.
  - Run `az aks get-credentials` from the jump host to obtain cluster credentials.
- Validate you can:
  - `kubectl get nodes`
  - `kubectl get pods -A`

2.2 Workload Identity plumbing:

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 2.5 Complete Workload Identity Path

- Confirm AKS OIDC + Workload Identity enabled
- Create one or more Entra app registrations / workload identities for:
  - Postgres access
  - Key Vault access
  - Service Bus access
- Wire Azure roles:
  - Key Vault (e.g. Key Vault Secrets User)
  - Postgres (via AAD integration if used)
  - Service Bus (Contributor/Owner/Specific roles)
- Document full path from pod → Service Account → Federated Credential → Entra → role

2.3 Key Vault CSI Driver:

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 2.4 Key Vault CSI Binding

- Install Secrets Store CSI driver + Key Vault provider into cluster
- Configure a sample Pod that:
  - Uses Workload Identity

2.4 Egress Hardening via UDR and Azure Firewall

**Goal:**
All outbound traffic from AKS nodes and pods must exit through Azure Firewall's data-plane public IP. AKS's default outbound public IP is no longer used.

Note: Due to free-tier public IP and vCPU constraints in this lab, steps 2.4.1–2.4.3 are implemented during the initial cluster bring-up rather than deferred to a later hardening pass.

---

2.4.1 Route table for AKS nodes

Create a route table in `rg-trench-aks-dev`:
- Name: `rt-aks-nodes-dev`
- Routes:
  - Destination: `0.0.0.0/0`
  - Next hop type: `VirtualAppliance`
  - Next hop IP: Azure Firewall private IP (from `AzureFirewallSubnet`).

**Outcome:**
- A route table exists that forces all node and pod egress toward the firewall.

---

2.4.2 Associate route table to `aks-nodes` subnet

Associate `rt-aks-nodes-dev` with the `spoke_aks_nodes` subnet.

**Outcome:**
- The subnet that hosts AKS nodes is configured to send outbound traffic to the firewall.

---

2.4.3 Switch AKS to userDefinedRouting

Update the AKS cluster resource:

```hcl
network_profile {
  network_plugin    = "azure"
  load_balancer_sku = "standard"
  outbound_type     = "userDefinedRouting"
}
```

**Outcome:**
- AKS stops using the managed outbound LB IP for SNAT and expects UDR-based egress.

---

2.4.4 Tighten Firewall rules

Remove the temporary "allow all" rule collection and add explicit outbound rules for:

- `AzureKubernetesService` (FQDN tag)
- `AzureContainerRegistry` (FQDN tag)
- Any other Internet endpoints required by workloads (for example, external APIs)

Note: Traffic to Key Vault and Postgres Flexible over Private Endpoints
remains inside the VNet and is governed by their network ACLs and Private Link
configuration rather than Azure Firewall egress rules. Service Bus uses a
public endpoint and is controlled via its own firewall/network rules and RBAC.

**Outcome:**
- Only explicitly allowed Internet-bound traffic can leave the cluster.

---

2.4.5 Validate egress path

From a test pod inside AKS:
- Run `curl https://ifconfig.io` (or similar).
- The visible IP must match the firewall’s data-plane public IP.
- If you block the firewall’s outbound rules temporarily, pod egress should fail.

**Outcome:**
- Confirmed that all pod and node egress traverses Azure Firewall.

---

2.5 Azure Platform Additions (Terraform)

Complete all remaining Azure infrastructure via Terraform before moving to Kubernetes manifests.

---

2.5.1 Log Analytics and Container Insights

- Create a Log Analytics workspace in `rg-trench-core-dev`.
- Enable AKS Container Insights via the `oms_agent` block in the AKS resource.
- Configure diagnostic settings to send AKS control-plane logs to Log Analytics.

**Outcome:**
- Azure-side telemetry is flowing; you can view container logs and metrics in Azure Portal.

---

2.5.2 Service Bus network rules

- Update Service Bus namespace to:
  - Set default action to `Deny`.
  - Allow only the Azure Firewall data-plane public IP.
  - Allow any required admin IPs or VPN ranges.

**Outcome:**
- Service Bus is no longer open to the internet; only cluster egress (via Firewall) can reach it.

---

2.5.3 Remote backend storage account

- Create an Azure Storage account and container for Terraform state.
- Do **not** migrate to the remote backend yet; that happens in Phase 8.10.
- This ensures the storage account exists and is ready when you automate Terraform.

**Outcome:**
- Storage account provisioned; local backend still in use for now.

---

Checkpoint (Phase 2):
- Jump host provisioned and cluster accessible
- Workload Identity plumbing complete
- Key Vault CSI driver add-on enabled
- Egress from AKS forced through Azure Firewall
- Log Analytics + Container Insights enabled
- Service Bus network-locked
- Remote backend storage account exists

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 5.3 Firewall / Egress Rules (failure lab - test by temporarily blocking egress rules)

After Phase 2, all Azure Terraform is complete. A single `terraform apply` provisions the entire platform.

---

## Phase 3: Observability Stack

**Goal:** Deploy in-cluster observability (Prometheus, Grafana, OTEL) via Kubernetes manifests.

Note: AKS and other Azure resources already send control-plane diagnostics to Log Analytics (Phase 2.5.1). In this phase you focus on in-cluster observability and add an internal NGINX Ingress Controller so you can reach dashboards (Grafana, ArgoCD, etc.) without constant `kubectl port-forward`. Public TLS endpoints remain in Phase 5.

Steps:

### 3.0 Kustomize structure for manifests

- Establish a Kustomize layout for Kubernetes manifests:
  - `k8s/base/` for reusable base manifests.
  - `k8s/overlays/dev/` for dev-specific overrides (and later `prod`, etc.).
- Ensure ArgoCD/GitOps in Phase 7 can target environment overlays rather than raw manifests.

---

### 3.1 Internal Ingress for observability

- Install NGINX Ingress Controller via Helm:
  - Deploy to the system node pool.
  - Use an internal Service (ClusterIP or internal LoadBalancer).
- Expose:
  - Grafana and other admin UIs behind internal hostnames.
- Validate:
  - Controller pods are running.
  - You can reach Grafana/Prometheus via the internal ingress from the jump host or VPN.

---

### 3.2 Prometheus + Grafana

- Deploy kube-prometheus-stack via Helm:
  - Prometheus for metrics collection
  - Grafana for dashboards
- Configure:
  - Scraping of Kubernetes components (kubelet, apiserver, etc.)
  - Scraping of app namespaces (ServiceMonitors)
- Import standard Kubernetes dashboards into Grafana.

---

### 3.3 OTEL Collector

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 3.1 OTel Collector Deployment

- Deploy OpenTelemetry Collector in its own namespace.
- Configure receivers:
  - OTLP (gRPC and HTTP) for app telemetry
- Configure exporters (minimal scope):
  - Prometheus metrics via kube-prometheus-stack (no additional OTEL metrics backends).  

---

## Phase 4: Ingress, TLS, and First Demo App

**Goal:** Create the first browser-to-pod HTTP path with TLS, using a minimal demo app.

Full firewall/UDR/NAT policy expansion will be incremental. Minimal egress lockdown first; detailed rule-set and DNS proxying moved to Phase 8.

Steps:

### 4.1 DNS

- Register or select a domain for the project.
- Configure a DNS zone (Cloudflare or other provider).
- Create an A or CNAME record for a demo hostname (e.g. `demo.dev.yourdomain.com`).
- Optionally provision the Cloudflare zone via Terraform.

---

### 4.2 Ingress Controller

- If you did not already install NGINX Ingress Controller in Phase 3:
  - Install it via Helm into the cluster.
  - Deploy to the system node pool.
  - Use an internal Service (ClusterIP or internal LoadBalancer) or other topology appropriate for your environment.
- If it already exists from Phase 3:
  - Reuse the same controller for the first public HTTP path.
- Validate the controller pods are running and ready to serve external traffic.

---

### 4.3 Tiny demo app

- Deploy a simple echo or health-check app:
  - Deployment + Service
  - Ingress resource with TLS enabled
- Validate end-to-end:
  - Certificate is valid and trusted

---

Checkpoint (Phase 4):
- NGINX Ingress Controller running
- TLS certificate issued via Let's Encrypt
- Demo app reachable over HTTPS from a browser

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 2.1 Deployment + Service + Ingress
- 6.1 Pod Pending Scenarios
- 6.2 Pod Running but Not Ready / Non-responsive
- 6.3 Service / Endpoint Failures

---

## Phase 5: CI/CD & GitOps Bootstrap

**Goal:** Establish automated build and deployment pipelines for the demo app.

Now that we have a working demo app, we set up the CI/CD mechanics before building real services. This ensures all future work happens in a GitOps-first workflow.

Steps:

### 5.1 GitHub Actions – CI for demo app

- Create a basic workflow to:
  - Build the demo app container image
  - Run linting / basic tests
  - Scan image with Trivy
  - Push image to ACR
- Trigger on commits to `main` or PRs

---

### 5.2 ArgoCD installation

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 2.3 ArgoCD Application + Kustomization

- Install ArgoCD into the AKS cluster (via Helm):
  - Create the `argocd` namespace in the cluster.
  - Install the ArgoCD chart into that namespace.
  - Expose ArgoCD via internal Ingress (reuse NGINX from Phase 4).
- Access ArgoCD UI and retrieve admin credentials.

---

### 5.3 GitOps for demo app

- Structure `k8s/` manifests with Kustomize:
  - `k8s/base/apps/` for base app manifests
  - `k8s/overlays/dev/apps/` for dev-specific overrides
  - `k8s/infra/` for infra add-ons (Prometheus, Grafana, OTEL, NGINX, cloudflared, etc.) with corresponding ArgoCD Applications in later phases
- Create an ArgoCD Application for the demo app:
  - Point to the Git repo + path
  - Set sync policy (manual or auto)
- Validate:
  - ArgoCD syncs and deploys the demo app
  - Changes to manifests in Git trigger redeployment

---

### 5.4 Image promotion flow

- Define how image tags flow from CI → manifests:
  - CI builds image with tag (e.g. commit SHA)
  - CI updates Kustomize image ref in Git
  - ArgoCD detects change and syncs
- Validate end-to-end:
  - Code change → CI build → manifest update → ArgoCD sync → pod rollout

---

Checkpoint (Phase 5):
- GitHub Actions builds and pushes demo app images to ACR
- ArgoCD deploys demo app from Git
- A single commit triggers the full CI/CD flow

---

## Phase 6: Application Services + Data Integration

**Goal:** Build real application services and integrate them with Postgres, Cosmos DB, and Service Bus.

Now that CI/CD is in place, we build actual services and wire them to the data/messaging layer as each service needs it.

Steps:

### 6.1 Domain definition

- Define a simple business/domain scenario:
  - Enough to justify:
    - User accounts (via External ID)
    - A few write/read operations
    - Use of messaging (e.g. background processing)
    - Use of both Postgres and Cosmos DB
- Document this domain at a high level (no full DDD, just enough structure).

---

### 6.2 Catalog API (Postgres integration)

- Implement `catalog-api` service:
  - Provides catalog/product data
  - Reads from Postgres `catalog` database
- **Postgres integration steps:**
  - Validate Postgres Flexible Server connectivity from cluster
  - Private Endpoint resolution works
  - Create `catalog` database schema (manual or via migration script)
  - Configure Kubernetes ServiceAccount for `catalog-api`
  - Bind ServiceAccount to Workload Identity federated credentials
  - Validate connection using Workload Identity / AAD auth
- Deploy via ArgoCD (reuse GitOps flow from Phase 5)
- Service includes:
  - OTEL for traces / metrics
  - Structured logging to stdout
  - Readiness/liveness probes
  - Basic resilience (timeouts, retries)

---

### 6.3 Orders API (Postgres integration)

- Implement `orders-api` service:
  - Handles cart and order operations
  - Writes to Postgres `orders` database
- **Postgres integration steps:**
  - Create `orders` database schema
  - Configure ServiceAccount and Workload Identity
  - Validate write operations
- Deploy via ArgoCD
- Service includes same observability/resilience patterns as `catalog-api`

---

### 6.4 Order Worker (Service Bus + Cosmos DB integration)

- Implement `order-worker` background service:
  - Listens to Service Bus `orders` queue
  - Processes order events and writes to Cosmos DB
- **Service Bus integration steps:**
  - Validate Service Bus connectivity from cluster
  - Egress through Firewall reaches the namespace
  - Network rules (from Phase 2.5.2) allow cluster traffic
  - Bind ServiceAccount to Service Bus RBAC roles
  - Test sending/receiving messages from `orders` queue
- **Cosmos DB integration steps:**
  - Ensure Cosmos DB account, database, and container exist (provisioned in Terraform)
  - Store Cosmos DB connection details (endpoint and keys) in Key Vault
  - Mount Cosmos DB settings via Key Vault CSI and Workload Identity
  - Document: this is lab-only sizing, not production-grade
- Deploy via ArgoCD
- Service includes same patterns as other services

---

### 6.5 UI (Next.js) in AKS

- Create a basic Next.js app:
  - Server-side rendered pages
  - Auth flows using Entra External ID
- Containerize and deploy to AKS behind Ingress:
  - Integrate with backend services

---

### 6.6 Entra External ID integration

- Configure B2C / External ID tenant
- Register apps:
  - UI
  - Backend APIs
- Implement:
  - Login / logout
  - MFA (enforced via policies)
  - Google social login
- Validate tokens and scopes in backend

---

### 6.7 Observability integration

- Prepare and apply observability patterns in the services:
  - Structured logging (JSON to stdout).
  - OTEL tracer initialization.
  - Metrics (counters, histograms) for HTTP requests.
- Confirm traces flow through end-to-end:
  - UI → API → downstream services → DB / Service Bus.
- Add Grafana dashboards for:
  - Per-service metrics.
  - Error rates and latencies.

Note: GitOps is limited to a single environment overlay for now. Multi-environment GitOps hierarchy moved to Phase 8.

Checkpoint (Phase 6):
- All services deployed via ArgoCD
- Postgres, Cosmos DB, and Service Bus integrated with respective services
- No static secrets; all auth via Workload Identity or Key Vault CSI
- A user can:
  - Log in via Entra External ID
  - Perform a simple workflow that writes to Postgres, stores something in Cosmos DB, and triggers a Service Bus message
  - See the whole flow in metrics, logs, and traces

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 2.2 NetworkPolicy (requires an app that talks to Postgres and Service Bus)
- 4.2 Application Integration
- 5.1 NetworkPolicy Default Deny in Namespace
- 5.2 Private DNS Mapping Issues (failure lab - test by removing Private DNS link)
- 6.4 DNS Failure Scenarios
- 6.5 Egress Block Failures

### 6.8 Alerting and SLOs

**Learning Objective Checkpoint**

The following learning objectives are to be completed as part of this phase:
- 3.2 SLO Setup

- Define one service-level objective (SLO):
  - Target: `success_rate >= 99.9%` over 30-day window
  - SLI: `sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))`
- Configure Prometheus alert rules:
  - Multi-window multi-burn-rate alerts for SLO violations
    - Fast burn (1h window): immediate page
    - Slow burn (6h window): warning
  - Reference: Google SRE Workbook burn-rate alerting methodology
  - Additional alerts for:
    - High error rate
    - High latency (p95/p99)
    - CPU/memory saturation
- Configure Alertmanager or Grafana alerts:
  - Email notifications to admin address
- Validate:
  - Temporarily break a route to trigger alerts

---

## Phase 7: Advanced CI/CD, Rollout Patterns & Failure Labs

**Goal:** Harden CI/CD pipelines, practice rollout scenarios, and run failure labs.

Now that basic CI/CD is working, we add advanced patterns and deliberately break things to learn recovery.

Steps:

### 7.1 Expand CI pipelines

- Enhance GitHub Actions workflows for all services:
  - Run unit tests
  - Run linting / static analysis
  - Run SonarQube/SonarCloud analysis
  - Multi-stage builds for optimization
  - Parallel jobs for faster builds

---

### 7.2 Deployment safety patterns

- Add to all services:
  - Readiness/liveness probes (if not already present)
  - Rolling update strategies with maxUnavailable/maxSurge
  - PodDisruptionBudgets for critical services
  - HPA manifests for key services

---

### 7.3 Rollout & rollback labs

---

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 7.1 Good Rollout
- 7.2 Bad Rollout
- 7.3 GitOps Rollback
- 7.4 Drift Correction

- **Good rollout:**
  - Deploy a new version of a service
  - Validate health checks pass
  - Monitor SLOs remain green
- **Bad rollout:**
  - Deploy a version with broken readiness probe
  - Observe rollout stalls
  - SLOs degrade
- **GitOps rollback:**
  - `git revert` the bad commit
  - ArgoCD syncs and restores health
- **Drift correction:**
  - Manually scale a Deployment to wrong replica count
  - ArgoCD detects drift and reverts it (if self-heal enabled)

---

### 7.4 Infra Terraform automation

- Create a GitHub Actions workflow (or equivalent) to:
  - Run `terraform fmt`, `terraform validate`, and `terraform plan` on pull requests affecting `infra/terraform/`.
  - Run `terraform apply` for approved changes to the dev environment.
- This replaces the manual `terraform apply` approach used in Phase 1.

---

### 7.5 ACR hardening

- Disable the ACR admin user.
- Ensure only Entra / workload identities (including CI via federated credentials) and RBAC roles (such as `AcrPull` / `AcrPush`) are used for registry access.
- Optionally tighten ACR network rules for non-lab environments (for example, restricting access to specific egress paths or private endpoints if introduced later).

Checkpoint (Phase 7):
- CI pipelines include tests, scans, and quality gates
- Deployment safety patterns applied to all services
- Rollout/rollback scenarios practiced and documented
- Terraform automation in place for infrastructure changes
- ACR hardened (no admin user, RBAC only)

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 8.1 Add HPA

---

## Phase 8: Cloudflare & Advanced Topics

**Goal:** Add Cloudflare Tunnel as a secure front door, WAF/rate limiting, and other advanced capabilities.


### 8.0 TLS with cert-manager

- Install cert-manager via Helm.
- Configure a ClusterIssuer for Let's Encrypt:
  - Use HTTP-01 solver for simplicity, or
  - Use DNS-01 with your DNS provider's API.
- Create a Certificate resource for the demo hostname.
- Validate the certificate is issued successfully.


### 8.1 Cloudflare Tunnel (cloudflared)

- Create a Cloudflare Tunnel:
  - Install `cloudflared` locally and establish a tunnel manually first.
  - Map the tunnel to your existing Ingress to validate end-to-end.
- Migrate tunnel into AKS:
  - Deploy `cloudflared` as a Deployment in an `infra-cloudflare` namespace.
  - Configure it to connect to the same tunnel.
  - Route traffic to the internal NGINX Ingress Service.

**Outcome:**
- External traffic flows: Browser → Cloudflare → Tunnel → AKS Ingress → Pod.
- No public LoadBalancer IP exposed.

---

### 8.2 Cloudflare WAF & rate limiting

- On an appropriate Cloudflare plan:
  - Enable WAF rules for the domain.
  - Configure rate limiting for sensitive endpoints (e.g. login, API).
- Document what is handled at Cloudflare edge vs in-cluster.

---

### 8.3 Direct Key Vault usage

- Replace CSI in a test service with:
  - Direct Key Vault SDK calls + caching
- Compare and document tradeoffs

---

### 8.4 Service mesh

- Introduce Istio or Linkerd:
  - mTLS between services
  - Traffic shifting
  - Mesh-level observability

---

### 8.5 Dapr

- Introduce Dapr for:
  - Service invocation
  - Pub/Sub over Service Bus
  - State store abstraction (e.g. Postgres/Redis)

---

### 8.6 Azure Application Gateway + AGIC (alternative front door)

- Provision an Azure Application Gateway with WAF enabled via Terraform.
- Install and configure the Application Gateway Ingress Controller (AGIC) for AKS.
- Route traffic from Cloudflare (or DNS) → App Gateway → NGINX Ingress → services.
- Compare this pattern with the Cloudflare Tunnel + NGINX-only approach used earlier in the lab.

---

### 8.7 Full Observability

- Deploy:
  - Tempo for traces
  - Loki for logs
- Switch OTEL Collector exports to Tempo/Loki.
- Logs and traces to a single backend (for example, Azure Monitor / Application Insights).
- Define pipelines:
  - Traces: OTLP → Azure Monitor (or another single chosen backend).
  - Logs: stdout scraping or OTLP → Azure Monitor.
- Compare with Azure Monitor-based setup.

---

### 8.8 Split AKS system, infrastructure, and user node pools

- Re-enable the dedicated `user` and `infra` node pools in Terraform with an appropriate, supported VM SKU (for example `Standard_D2ls_v5` or similar) once the subscription has sufficient vCPU quota.
- Keep the `system` pool small and stable for control-plane and platform add-ons
- Direct application workloads to the `user` pool, and observability to the `infra` node pool using:
  - Node labels / `nodeSelector` / `nodeAffinity`.
  - Taints and tolerations if you want to keep system, infra and user workloads strongly separated.
- Update documentation to reflect the new scheduling model and any resource requests/limits tuned for the new pool layout.
- Validate that:
  - System components remain on the `system` pool.
  - Prometheus, Grafana, NGINX Ingress, cert-manager on the `infra` pool.
  - Application pods land on the `user` pool by default.

---

### 8.9 Event-driven autoscaling with KEDA

- Install KEDA into the cluster (via Helm or ArgoCD):
  - Deploy the KEDA operator into its own namespace.
  - Confirm KEDA CRDs are installed.
- Configure one or more KEDA ScaledObjects:
  - Scale `order-worker` from Azure Service Bus queue length.
  - Optionally scale an API deployment from HTTP metrics or CPU.
- Validate scaling behavior:
  - Generate load (for example, enqueue messages) and observe pod count changes.
  - Confirm scaling down when load subsides.
- Compare:
  - HPA-only scaling from Phase 7.4 vs. KEDA event-driven scaling.
  - Document trade-offs and when to use each.

---

### 8.10 Terraform remote backend migration

- The storage account was created in Phase 2.5.3; now migrate to use it.
- Update `backend.tf` to use the `azurerm` backend, pointing at that storage account/container.
- Update CI workflows (7.5) to initialize and use the remote backend.
- Decommission the local backend file used in Phase 1 once the remote backend is live and validated.

---

### 8.11 Terraform structure refactor (modules + env overlays)

- Refactor Terraform configuration so that:
  - Shared infrastructure lives in reusable modules (for example, `infra/terraform/modules/core`).
  - Each environment (`dev`, and later `prod`) has a thin `env/<env>/` layer that wires variables and backends.
- Keep behavior identical; the goal is a cleaner structure for future environments, not new features.

---

**Learning Objective Checkpoint**

The following learning objectives can now be completed:
- 8.2 Generate Traffic
- 8.3 Trigger DB saturation scenario
- 8.4 Apply fixes