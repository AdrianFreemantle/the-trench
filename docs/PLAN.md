# Plan

## Phase 0: Repo, Structure, and Working Agreements

**Goal:** Establish repo structure, tooling choices, and conventions before writing infra or app code.

Current Step: 1
Completed Stes: 0

Steps:
## Phase 0: Repository Setup, Conventions, and App Skeletons
Establish the repository structure, conventions, governance, and minimal service skeletons needed for later infrastructure and CI/CD work.  
No real business logic yet. Only “hello world” containers to ensure everything builds and runs.

0.1 Create mono-repo

Repository name: `cloud-native-aks-lab` (or `the-trench`).

Top-level folders:

infra/
  terraform/          # Core Azure infra
  cluster-addons/     # Add-ons installed after cluster creation

apps/
  catalog-api/        # Node.js skeleton service
  orders-api/         # Python skeleton service
  order-worker/       # Node.js skeleton worker
  shop-ui/            # Next.js skeleton UI

ops/
  adr/                # Architecture Decision Records
  runbooks/           # Operational docs
  docs/               # Architecture and planning docs

k8s/
  apps/               # Workload manifests (later)
  infra/              # Add-ons managed via GitOps (later)

ci/
  github/             # GitHub Actions pipelines (build-only in early phases)

Add placeholder README files in each top-level folder where necessary.

---

0.2 Define coding and infra conventions

Document in `CONVENTIONS.md`:

- Preferred languages:
  - Node.js 20 for catalog-api and order-worker
  - Python 3.12 for orders-api
  - Next.js with TypeScript for shop-ui

- Container base images:
  - node:20-slim
  - python:3.12-slim

- Naming conventions:
  - Azure: trench-<service>-<resource>-<env>
  - Kubernetes: <service>-<component>

- Tagging strategy:
  - owner
  - environment
  - cost-center
  - purpose

---

0.3 ADR Template

Under `ops/adr/` add:

- `template.md`:
  - Context
  - Options considered
  - Decision
  - Consequences

---

0.4 Initialize Git + GitHub repo

- Initialize git locally.
- Add top-level `.gitignore`:
  - Terraform
  - Node.js
  - Python
  - Next.js
  - Docker-related ignores

- Create initial `README.md`:
  - Summary of project purpose
  - Phase structure
  - High-level architecture goals

Push to GitHub.

---

0.5 Create minimal service skeletons (no logic)

Create **very minimal** app scaffolds so CI, containers, and AKS later have something to deploy.

- catalog-api (Node.js)
  - index.js: express server with `/healthz`
  - Dockerfile
  - package.json

- orders-api (Python)
  - main.py with FastAPI `/healthz`
  - requirements.txt
  - Dockerfile

- order-worker (Node.js)
  - worker.js with log: “worker running”
  - Dockerfile
  - package.json

- shop-ui (Next.js)
  - Next.js “hello world” page
  - Dockerfile

- The goal:  
  - All services build as containers  
  - Each has a health endpoint  
  - Nothing more

---

0.6 Local docker-compose for developer sanity

Create `docker-compose.yml` to run all skeleton services together.  
No databases yet.  
Just prove containers run.

Services:
- catalog-api
- orders-api
- order-worker
- shop-ui

Optional:
- Local Postgres + Mongo to be added in Phase 6

---

0.7 Checkpoint

At the end of Phase 0:

- Repo structure exists
- Conventions documented
- ADR system in place
- GitHub repo initialized
- All four services exist as “hello world” containers
- Local docker-compose works

---

## Phase 1: Core Azure Infrastructure with Terraform

**Goal:** Provision the foundational Azure environment with Terraform: hub–spoke VNets, Firewall, ACR, private AKS, Key Vault, Postgres Flexible, Service Bus, and Private Endpoints.  
Execution is **manual `terraform apply`** for now; infra Terraform automation is introduced in **Phase 7.5**.

---

### 1.1 Terraform Bootstrap

Create and initialize `infra/terraform/`:

- Files:
  - `providers.tf`
  - `backend.tf` (local state for Phase 1; remote backend migration is handled in **Phase 7.7**)
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

Document that firewall rules are intentionally loose in Phase 1 and will be tightened in **Phase 2.6** (egress hardening via UDR and Azure Firewall).

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

Note: Due to AKS restricted-SKU rules for very small VM sizes and the tight free-tier vCPU quota in this subscription, the initial implementation temporarily runs with a **single** `system` node pool only. The `user` pool Terraform resource is commented out and will be reintroduced in a later hardening phase once the subscription is upgraded and larger SKUs are available without hitting quota limits.

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
- Initially allow broad access for simplicity; in Phase 5.4 you will tighten Service Bus network rules to allow only the Azure Firewall public IP (and any required admin IPs/VPN ranges).

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

2.2 Add-on deployment approach (GitOps with ArgoCD):
- Adopt ArgoCD GitOps as the source of truth for all cluster add-ons and application manifests.
- Document this decision in an ADR under `ops/adr/`, clarifying that Terraform bootstraps ArgoCD and ArgoCD manages in-cluster resources.
- Define repo structure for ArgoCD Applications, for example:
  - `k8s/infra-addons/` for CSI driver, Prometheus, Grafana, cloudflared, and other cluster add-ons.
  - `k8s/apps/` for application workloads.
- Treat Terraform as responsible only for Azure infrastructure and ArgoCD bootstrap, not for managing individual add-on Helm releases.

2.3 Install ArgoCD:
- Create the `argocd` namespace in the AKS cluster.
- Use Terraform with the Helm provider to install the ArgoCD chart into that namespace.
- Configure ArgoCD (via Helm values and/or a bootstrap `Application`) to:
  - Point at your Git repo.
  - Auto-sync the `k8s/infra-addons/` and `k8s/apps/` paths defined in 2.2.

2.4 Workload Identity plumbing:
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

2.5 Key Vault CSI Driver:
- Install Secrets Store CSI driver + Key Vault provider into cluster
- Configure a sample Pod that:
  - Uses Workload Identity
  - Mounts a Key Vault secret via CSI volume
- Confirm:
  - Pod can read secret from file
  - No Kubernetes Secret object created

### 2.6 Egress Hardening via UDR and Azure Firewall

**Goal:**
All outbound traffic from AKS nodes and pods must exit through Azure Firewall’s data-plane public IP. AKS’s default outbound public IP is no longer used.

Note: Due to free-tier public IP and vCPU constraints in this lab, steps 2.6.1–2.6.3 are implemented during the initial cluster bring-up rather than deferred to a later hardening pass.

---

2.6.1 Route table for AKS nodes

Create a route table in `rg-trench-aks-dev`:
- Name: `rt-aks-nodes-dev`
- Routes:
  - Destination: `0.0.0.0/0`
  - Next hop type: `VirtualAppliance`
  - Next hop IP: Azure Firewall private IP (from `AzureFirewallSubnet`).

**Outcome:**
- A route table exists that forces all node and pod egress toward the firewall.

---

2.6.2 Associate route table to `aks-nodes` subnet

Associate `rt-aks-nodes-dev` with the `spoke_aks_nodes` subnet.

**Outcome:**
- The subnet that hosts AKS nodes is configured to send outbound traffic to the firewall.

---

2.6.3 Switch AKS to userDefinedRouting

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

2.6.4 Tighten Firewall rules

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

2.6.5 Validate egress path

From a test pod inside AKS:
- Run `curl https://ifconfig.io` (or similar).
- The visible IP must match the firewall’s data-plane public IP.
- If you block the firewall’s outbound rules temporarily, pod egress should fail.

**Outcome:**
- Confirmed that all pod and node egress traverses Azure Firewall.

Checkpoint:
- ArgoCD running
- Workload Identity working for at least one test pod
- Key Vault CSI driver working

---

## Phase 3: Edge, Cloudflare, and Ingress

**Goal:** Expose the cluster securely via Cloudflare, using Cloudflare Tunnel and TLS.

Steps:

3.1 Cloudflare DNS:
- Register / select domain
- Configure DNS zone in Cloudflare
- Point domain’s NS records at Cloudflare

3.2 Cloudflare Tunnel (cloudflared):
- Create a Cloudflare Tunnel manually first:
  - Install `cloudflared` locally and establish a tunnel
  - Map tunnel to a test HTTP service to validate end-to-end
- Then migrate tunnel into AKS:
  - Deploy `cloudflared` Deployment in a `infra-cloudflare` namespace
  - Configure it to connect to the same tunnel
  - Use a Service + Ingress in AKS as origin

3.3 Ingress Controller:
- Install NGINX Ingress Controller (or similar) in AKS:
  - System node pool
  - Internal Service (ClusterIP or internal LoadBalancer depending on tunnel setup)
- Configure Ingress resource for a dummy app (e.g. simple echo service)

3.4 TLS with Let’s Encrypt and DNS-01:
- Install cert-manager
- Configure DNS-01 solver for Cloudflare:
  - Use Key Vault / CSI to store Cloudflare API token if needed
- Create Ingress with TLS using Let’s Encrypt:
  - Validate certificates issued successfully
  - Set Cloudflare to Full (Strict) mode

3.5 WAF and rate limiting:
- On appropriate Cloudflare plan:
  - Enable basic WAF rules for the domain
  - Configure rate limiting for specific paths (e.g. login endpoints)
- Document what is covered at Cloudflare vs in-cluster

Checkpoint:
- A test app is reachable via HTTPS over your domain:
  - Browser → Cloudflare → Tunnel → AKS Ingress → Pod

---

## Phase 4: Observability Stack (Initial)

**Goal:** Set up Prometheus, Grafana, OTEL, and basic alerting with exports to Azure Monitor.

Steps:

4.1 Prometheus + Grafana:
- Deploy Prometheus (likely kube-prometheus-stack) via ArgoCD/Helm
- Configure:
  - Scraping of Kubernetes components
  - Scraping of app namespaces
- Deploy Grafana:
  - Connect to Prometheus data source
  - Import basic Kubernetes dashboards

4.2 OTEL Collector:
- Deploy OpenTelemetry Collector in its own namespace:
  - Receivers for OTLP (from apps)
  - Exporters to:
    - Azure Monitor / App Insights / Log Analytics
- Define basic pipelines:
  - Traces: OTLP → Azure
  - Logs: OTLP or stdout scraping → Azure (or leave logs only in Azure Monitor at first)
  - Metrics: OTLP → Prometheus or directly to Azure if needed

4.3 App instrumentation baseline:
- Prepare libraries / patterns for:
  - Structured logging
  - OTEL tracer initialization
  - Metrics (counter, histogram) for HTTP requests

4.4 Alerting:
- Configure Prometheus alert rules:
  - High error rate
  - High latency
  - CPU/memory saturation
- Configure Alertmanager or Grafana alerts:
  - Email alerts to admin address

Checkpoint:
- You can see:
  - Cluster metrics in Grafana
  - At least one app’s metrics
  - Logs and/or traces in Azure Monitor
  - Test alerts hitting your email

---

## Phase 5: Data & Messaging Integration

**Goal:** Wire Postgres, Mongo, and Service Bus into the cluster with Workload Identity + Key Vault CSI.

Steps:

5.1 Postgres integration:
- Configure Postgres Flexible for:
  - AAD auth (if used) or MI-based connection
  - Private Endpoint confirmed
- Create initial schema (manual or migration):
  - For simplicity, initial migrations can be run via a CLI tool / script

5.2 Service identity for Postgres:
- Create Entra identity for backend services needing DB access
- Assign appropriate roles for Postgres
- Configure Kubernetes ServiceAccount + Workload Identity binding

5.3 MongoDB in AKS:
- Deploy MongoDB as:
  - StatefulSet
  - Headless Service
  - PVCs using appropriate Storage Class
- Minimal replica set for learning
- Document clearly that this is lab-only, not production-grade

5.4 Service Bus integration:
- Update Terraform to configure Service Bus namespace network rules so that:
  - Default action is deny.
  - Only the Azure Firewall data-plane public IP (and any required admin IPs/VPN ranges) are allowed.
- Create entities (queues/topics) via Terraform or script
- Create identity for messaging services and assign RBAC

5.5 Test workloads:
- Create small test pods / scripts that:
  - Connect to Postgres via MI
  - Connect to Mongo via internal service
  - Send/receive messages from Service Bus

Checkpoint:
- You have a working data/messaging layer accessible from the cluster without static secrets.

---

## Phase 6: Application Services (Backend + UI) – v1

**Goal:** Implement minimal but realistic app services that exercise the platform.

Steps:

6.1 Domain definition:
- Define a simple business/domain scenario:
  - Enough to justify:
    - User accounts (via External ID)
    - A few write/read operations
    - Use of messaging (e.g. background processing)
    - Use of both Postgres and Mongo
- Document this domain at a high level (no full DDD, just enough structure).

6.2 Backend services:
- Implement 2–3 small services, e.g.:
  - `api-gateway` or BFF for UI
  - `orders-service` (Postgres)
  - `events-service` (Mongo + Service Bus)
- Each service:
  - Uses OTEL for traces / metrics
  - Uses structured logging to stdout
  - Uses environment/config pattern aligned with 12-factor, while using Key Vault CSI for secrets
  - Implements basic resilience:
    - Timeouts
    - Retries
    - Circuit-breaking (via library or custom pattern)

6.3 UI (Next.js) in AKS – first iteration:
- Create a basic Next.js app:
  - Server-side rendered pages
  - Auth flows using Entra External ID
- Containerize and deploy to AKS behind Ingress:
  - Integrate with backend services

6.4 Entra External ID integration:
- Configure B2C / External ID tenant
- Register apps:
  - UI
  - Backend APIs
- Implement:
  - Login / logout
  - MFA (enforced via policies)
  - Google social login
- Validate tokens and scopes in backend

6.5 Observability integration:
- Confirm traces flow through:
  - UI → API → downstream services → DB / Service Bus
- Add Grafana dashboards for:
  - Per-service metrics
  - Error rates, latencies

Checkpoint:
- A user can:
  - Log in via Entra External ID
  - Perform a simple workflow that writes to Postgres, stores something in Mongo, and triggers a Service Bus message
  - You can see the whole thing in metrics, logs, and traces

---

## Phase 7: CI/CD and GitOps

**Goal:** Automate build, test, security checks, and deployments end-to-end.

Steps:

7.1 GitHub Actions – CI:
- Create workflows to:
  - Build each service image
  - Run unit tests
  - Run linting / static analysis
  - Run SonarQube/SonarCloud analysis
  - Build Next.js app
  - Build container images
  - Scan images with Trivy
  - Push images to ACR

7.2 GitOps with ArgoCD:
- Structure `k8s/` manifests/Helm charts:
  - `k8s/apps/` for app deployments
  - `k8s/infra-addons/` for Prometheus, Grafana, OTEL, cloudflared, etc.
- Configure ArgoCD Applications:
  - One per app or per group
- Set up ArgoCD to:
  - Watch main branches for changes
  - Auto-sync or manual-sync depending on desired workflow

7.3 Promotion flow:
- Define branch / tag strategy:
  - e.g. `main` for dev environment
- Define how:
  - A code change results in:
    - CI build + scan
    - Image push
    - Manifest update (tag change)
    - ArgoCD sync and rollout

7.4 Deployment safety:
- Add:
  - Readiness/liveness probes
  - Rolling update strategies
  - HPA manifests for key services
- Validate rollbacks via:
  - ArgoCD rollback or Git revert

7.5 Infra Terraform automation:
- Create a GitHub Actions workflow (or equivalent) to:
  - Run `terraform fmt`, `terraform validate`, and `terraform plan` on pull requests affecting `infra/terraform/`.
  - Run `terraform apply` for approved changes to the dev environment.
- This replaces the manual `terraform apply` approach used in Phase 1.

7.6 ACR hardening:
- Disable the ACR admin user.
- Ensure only Entra / workload identities (including CI via federated credentials) and RBAC roles (such as `AcrPull` / `AcrPush`) are used for registry access.
- Optionally tighten ACR network rules for non-lab environments (for example, restricting access to specific egress paths or private endpoints if introduced later).

7.7 Terraform remote backend migration:
- Create an Azure Storage account and container dedicated to Terraform state for this lab.
- Update `backend.tf` to use the `azurerm` backend, pointing at that storage account/container.
- Update CI workflows (7.5) to initialize and use the remote backend.
- Decommission the local backend file used in Phase 1 once the remote backend is live and validated.

Checkpoint:
- A single commit to main triggers:
  - CI build, tests, scans
  - Deployment to AKS via ArgoCD

---

## Phase 8: Hardening & Advanced Topics (Optional)

**Goal:** Add advanced, more “enterprise-like” capabilities.

Examples (each can be its own mini-phase):

8.1 Rate limiting & DDoS:
- More advanced Cloudflare rules
- App-level rate limiting for specific endpoints

8.2 Direct Key Vault usage:
- Replace CSI in a test service with:
  - Direct Key Vault SDK calls + caching
- Compare and document tradeoffs

8.3 Service mesh:
- Introduce Istio / Linkerd:
  - mTLS between services
  - Traffic shifting
  - Mesh-level metrics

8.4 Dapr:
- Introduce Dapr for:
  - Service invocation
  - Pub/Sub over Service Bus
  - State store abstraction (e.g. Postgres/Redis)

8.5 Full OSS observability:
- Deploy:
  - Tempo for traces
  - Loki for logs
- Switch OTEL exports to those
- Compare with Azure Monitor-based setup

8.6 Split AKS system and user node pools (post free-tier upgrade):
- Re-enable the dedicated `user` node pool in Terraform with an appropriate, supported VM SKU (for example `Standard_D2ls_v5` or similar) once the subscription has sufficient vCPU quota.
- Keep the `system` pool small and stable for control-plane and platform add-ons; direct application workloads to the `user` pool using:
  - Node labels / `nodeSelector` / `nodeAffinity`.
  - Taints and tolerations if you want to keep system and user workloads strongly separated.
- Update documentation to reflect the new scheduling model and any resource requests/limits tuned for the new pool layout.
- Validate that:
  - System components remain on the `system` pool.
  - Application pods land on the `user` pool by default.