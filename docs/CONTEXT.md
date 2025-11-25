# The Trench

## Constraints and Non-Goals

### Cost Constraints
- Self-funded; must be **cost-conscious**:
  - Prefer free or low-tier SKUs where possible
  - Design for tear-down / recreate to avoid constant runtime charges
- Azure WAF / Front Door WAF are likely too expensive for hands-on labs:
  - We’ll use **Cloudflare WAF + rate limiting** as the practical, affordable WAF story

### Scope Limits
- Single Azure region (e.g. South Africa North) for now
- Single environment (dev/test) initially:
  - Separate clusters/envs may be modeled conceptually or added later
- No attempt to create a fully enterprise-grade, multi-team platform:
  - This is a focused, realistic learning environment, not a full internal developer platform

### Kubernetes Secrets
- **No plain Kubernetes `Secret` objects** for sensitive data
- Secrets come from **Azure Key Vault**:
  - Accessed via **Key Vault CSI Driver** and **Entra Workload Identity**
- Later phase may introduce:
  - Direct Key Vault SDK access as a “hardening and advanced pattern”

## What we are building

The application itself is intentionally simple: a small set of cooperating services plus a UI. The complexity is in the **platform and operational model**, not in the business domain. The target audience is senior engineers and architects who want to move from theory and diagrams to actually building and running such a system.

### App Shape 

We will build a **small, but realistic, multi-service web application** consisting of:

- A **Next.js UI** (SSR) for users to:
  - Sign in via Entra External ID (with social login + MFA)
  - Perform a few core actions (create/update/read some domain entities)
- **2–3 backend services** (Python and/or Node.js) that:
  - Expose HTTP APIs (REST/gRPC) to the UI and each other
  - Use:
    - **Postgres** for relational data
    - **MongoDB** for document / event-style data
    - **Azure Service Bus** for async workflows and background processing

The exact domain is deliberately simple (e.g. some kind of “records/tasks/events” tracking), chosen to:

- Require:
  - Authenticated users
  - CRUD operations
  - Async processing and background workers
  - Use of both relational and document storage
- Avoid:
  - Heavy business rules
  - Domain complexity overshadowing the platform

### App Characteristics

Each service will be engineered as a **12-factor-style cloud-native service**, including:

- Stateless containers (no dependency on local disk)  
- Config and secrets externalized (Key Vault via CSI, plus non-sensitive env/config)  
- Structured logging to stdout/stderr  
- OpenTelemetry for traces and metrics  
- HTTP timeouts, retries, and circuit breakers for downstream calls  
- Health endpoints for readiness/liveness, used by Kubernetes

The focus is to **exercise the platform**:

- Ingress and routing through Cloudflare → Tunnel → AKS Ingress → services  
- Identity end-to-end (user tokens → API authZ, service identities → Azure resources)  
- Data access patterns with managed and self-hosted stores  
- Async messaging and background processing  
- Metrics, logs, and traces across multiple services and components

---

## Architecture Overview

### Cloud Platform

- **Azure** subscription dedicated to this project  
- **Region:** South Africa North (or equivalent)  
- Single environment (dev/test) initially; future multi-env is a later concern

### Network Topology

- **Hub-Spoke VNet architecture**:
  - Hub:
    - Azure Firewall
    - Shared infra
  - Spoke:
    - AKS subnet
    - Subnets for Private Endpoints
- **AKS is a private cluster**:
  - Private API endpoint
  - Controlled access via Bastion/VPN / secure access patterns
- **DNS**:
  - Internal: Azure Private DNS zones for Private Endpoints and internal services
  - External: Cloudflare as authoritative DNS

### Ingress & Edge

- **Cloudflare**:
  - DNS for public domain
  - **Cloudflare Tunnel** from AKS → Cloudflare edge (no public ingress IP)
  - SSL termination at Cloudflare and **re-encryption** to the cluster (Full/Strict)
  - **WAF + rate limiting** via Cloudflare (cost-effective alternative to Azure WAF)
- **Ingress Controller in AKS**:
  - NGINX Ingress Controller (or equivalent)
  - Receives traffic from Cloudflare Tunnel
  - Routes to backend services and UI

### Identity & Security

- **Entra Workload Identity**:
  - AKS workloads authenticate to Azure resources without static credentials
- **Azure Key Vault as secret store**:
  - All sensitive secrets stored in Key Vault
  - **Key Vault CSI Driver** mounts secrets into pods
  - **No plain Kubernetes Secrets** for sensitive values
- **Entra External ID (B2C)**:
  - Handles external user identities
  - Supports Google login + MFA
  - Used by the Next.js UI and backend APIs
- **Kubernetes RBAC**:
  - Cluster roles and bindings for:
    - Infra/ops
    - Application developers
    - Read-only roles

### Data & Messaging

- **Azure Database for PostgreSQL Flexible Server**:
  - Primary relational data store
  - Private Endpoint in the VNet
  - Minimal dev/test SKU to control cost
- **Self-hosted MongoDB in AKS**:
  - StatefulSet + PVCs
  - Used to learn stateful workloads and discuss why self-hosted DBs in AKS are risky in production
- **Azure Service Bus**:
  - Main messaging backbone
  - Workload Identity + RBAC for access from services
  - Used for async processing and decoupling between services

### Application Components

- **Backend services** (2–3 services):
  - Python and/or Node.js
  - REST/gRPC APIs
  - Use Postgres, Mongo, and Service Bus
  - Implement:
    - OTEL tracing/metrics
    - Structured logging
    - Resilience patterns (timeouts, retries, circuit breakers)
- **Next.js UI**:
  - SSR-based app
  - Integrates Entra External ID auth flows
  - Calls backend services via ingress
  - **v1:** deployed as a container in AKS  
  - **v2:** static export hosted in Blob Storage + Cloudflare (to demonstrate moving workloads out of the cluster for cost/simplification)

### Observability

- **Prometheus**:
  - Metrics from Kubernetes + apps
- **Grafana**:
  - Dashboards for:
    - Cluster health
    - App-level metrics
- **OpenTelemetry Collector**:
  - OTLP receiver for traces/metrics/logs
  - Export to Azure Monitor / Log Analytics / App Insights (in v1)
- **Alerting**:
  - Prometheus alert rules for error rate, latency, saturation
  - Alerts delivered via email for now

### CI/CD & GitOps

- **Terraform**:
  - Provisions:
    - Resource groups
    - VNets (hub/spoke)
    - AKS cluster + node pools
    - ACR
    - Key Vault
    - Postgres Flexible
    - Service Bus
    - Private Endpoints
    - DNS zones and records
  - Local state initially; can evolve to Azure Storage backend for state later
- **GitHub Actions**:
  - CI for services and UI:
    - Build and tests
    - Static analysis via SonarQube/SonarCloud
    - Container scanning (e.g. Trivy)
    - Push images to ACR
- **ArgoCD**:
  - GitOps deployment for:
    - Application workloads
    - Cluster add-ons (Prometheus, Grafana, OTEL, cloudflared, etc.)
  - Declarative rollout and rollback via Git changes

---

## Key Decisions 

1. **AKS (private) over Functions/Container Apps**  
   - Chosen to learn cluster-level operations and networking; more complex but aligned with project goals.

2. **Cloudflare Tunnel + WAF instead of Azure Front Door/App Gateway WAF**  
   - Dramatically cheaper for a self-funded, always-on lab.  
   - Still realistic: many teams adopt this pattern.

3. **Hub-Spoke networking with Azure Firewall**  
   - Mirrors enterprise patterns and gives room to discuss segmentation, Private Endpoints, and egress control.

4. **Workload Identity + Key Vault CSI, no plain K8s Secrets**  
   - Security-first approach for secrets.  
   - Accepts Azure lock-in as a reasonable tradeoff for correctness and realism in Azure shops.

5. **Postgres Flexible as managed RDBMS, self-hosted Mongo as NoSQL**  
   - Postgres Flexible: realistic managed option.  
   - Mongo in AKS: intentionally “not best practice” but used to teach stateful workloads and tradeoffs.

6. **Azure Service Bus as primary messaging**  
   - Reflects typical Azure-native architecture.  
   - Queues/topics for async flows and background workers.

7. **Prometheus + Grafana + OTEL + Azure Monitor for v1**  
   - Strong baseline that matches what many Azure shops actually run.  
   - Full OSS stack (Tempo, Loki) reserved for a later advanced phase.

8. **GitHub Actions (CI) + ArgoCD (GitOps)**  
   - Modern, widely used pair.  
   - Clear separation: CI builds artifacts, CD is declarative and pull-based.

9. **No service mesh / Dapr in phase 1**  
   - Native mechanics first; service mesh and Dapr come later as explicit “this is how we simplify things once we understand them.”

10. **12-factor as guiding principle, not a religion**  
    - We follow the spirit: stateless, external config, logs-as-streams, build/release/run separation.  
    - We deviate where cloud-native realities (Key Vault, CSI, managed services) make more sense, and we document those deviations.
