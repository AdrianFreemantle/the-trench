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
Execution is **manual `terraform apply`** for now; CI/CD for infra comes later.

---

### 1.1 Terraform Bootstrap

Create and initialize `infra/terraform/`:

- Files:
  - `providers.tf`
  - `backend.tf` (local state for Phase 1)
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
- Assign a public IP (for now).
- Create a **minimal** rule set:
  - Network rules / application rules sufficient for:
    - AKS control plane connectivity.
    - Node pool image pulls from ACR / Microsoft endpoints.
  - Everything else denied by default.

Document that firewall rules are intentionally loose in Phase 1 and will be tightened in later phases.

**Outcome:**
- Egress from the AKS spoke will be forced through Firewall (once UDRs are configured in later phases).

---

### 1.5 Azure Container Registry (ACR)

Deploy ACR into `rg-trench-core-dev`:

- Basic SKU to control cost.
- Naming consistent with conventions (for example `trenchacrcoredev`).

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
- Two node pools:
  - `system` pool (small SKU, system workloads only).
  - `user` pool (for app workloads later).

Also:

- Configure AKS to use the ACR created in 1.5 (either via `azurerm_kubernetes_cluster` `acr` integration or role assignment).

**Outcome:**
- A private AKS cluster exists and can pull images from ACR (once CI pushes them).
- `az aks get-credentials` works from a machine with network access (via VPN/Bastion in a later phase).

---

### 1.7 Azure PaaS: Key Vault, Postgres Flexible, Service Bus

Provision the minimal PaaS set in Terraform.

**Key Vault (rg-trench-core-dev)**

- Standard SKU.
- Soft-delete enabled.
- Private Endpoint into `private-endpoints` subnet in the spoke VNet.
- Network ACLs locked to:
  - Private link only
  - Trusted Azure services as needed.

**PostgreSQL Flexible Server (rg-trench-data-dev)**

- Dev-grade SKU (smallest viable tier).
- Private access only (no public endpoint).
- Private Endpoint into `private-endpoints` subnet.
- Server to host schemas for:
  - `catalog-api`
  - `orders-api`

**Service Bus (rg-trench-core-dev)**

- Service Bus namespace.
- Messaging entities:
  - Topic or queue for `OrderPlaced` (e.g. `orders`).
- Private Endpoint into `private-endpoints` subnet.

**Outcome:**
- All core PaaS resources exist, but no identities, roles, or workloads use them yet.

---

### 1.8 Private DNS for PaaS / Private Endpoints

Configure Azure Private DNS zones and links for:

- Key Vault `privatelink.vaultcore.azure.net`
- Postgres Flexible `privatelink.postgres.database.azure.com`
- Service Bus `privatelink.servicebus.windows.net`

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
  - Service Bus namespace + `OrderPlaced` entity (with Private Endpoint)
  - Private DNS zones and links for all of the above

You **do not** yet:

- Install ArgoCD, ingress controllers, CSI drivers, Prometheus/Grafana, or any app workloads.
- Automate Terraform via CI/CD.

Those belong in **Phase 2** (cluster add-ons + identity plumbing) and later phases.

---

## Phase 2: Cluster Add-ons and Security Plumbing

**Goal:** Install core cluster add-ons and wire Workload Identity and Key Vault CSI.

Steps:

2.1 Cluster access:
- Configure local kubectl access via:
  - Az CLI (`az aks get-credentials` with private endpoint access and/or Bastion/VPN)
- Validate you can:
  - `kubectl get nodes`
  - `kubectl get pods -A`

2.2 Add-on deployment approach:
- Decide:
  - Use Terraform + Helm provider
  - Or use ArgoCD to manage add-on Helm charts
- For initial simplicity, you can:
  - Install ArgoCD via Terraform/Helm
  - Then let ArgoCD manage the rest

2.3 Install ArgoCD:
- Namespace (e.g. `argocd`)
- Deploy ArgoCD using Helm or manifests
- Configure ArgoCD to sync from your Git repo

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

Note: Traffic to Key Vault, Postgres Flexible, and Service Bus over Private Endpoints
remains inside the VNet and is governed by their network ACLs and Private Link
configuration rather than Azure Firewall egress rules.

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
- Ensure Service Bus Private Endpoint and DNS resolution are correct
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