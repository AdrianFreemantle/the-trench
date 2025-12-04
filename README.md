# The Trench: Azure AKS Cloud-Native Lab

This repository contains a full end-to-end, production-inspired cloud-native platform built on Azure Kubernetes Service (AKS). The purpose is to move beyond theory and actually build, operate, and manage a realistic cluster with proper networking, security, identity, data, observability, CI/CD, and GitOps.

The application domain is intentionally simple. The complexity and learning value come from the platform itself.

## Objective

Build a private, enterprise-grade AKS environment using modern Azure patterns, Cloudflare for ingress, Workload Identity, Terraform, ArgoCD, GitHub Actions, and a small set of services engineered to production standards.

This project is a teaching and capability-building exercise: how to design, provision, secure, deploy, observe, scale, and operate distributed systems on AKS.

## Core Architecture (High Level)

- Private AKS cluster (private API, no public ingress)
- Hub-spoke VNet topology with Azure Firewall
- Cloudflare DNS and Cloudflare Tunnel as the only ingress path
- Azure Key Vault for secrets via CSI driver
- Workload Identity for Pod-to-Azure authentication
- Postgres Flexible Server (managed) + Azure Cosmos DB (NoSQL)
- Azure Service Bus for async messaging
- Next.js UI + 2–3 backend services (Node/Python)
- Prometheus, Grafana, OTEL Collector, Azure Monitor
- Terraform for all Azure infra
- GitHub Actions for CI
- ArgoCD for GitOps-driven deployments

## Repository Structure

.
├── infra/                         # All infrastructure code
│   ├── terraform/                 # Azure TF modules and root configs
│   └── cluster-addons/            # ArgoCD, ingress, CSI driver, Prometheus, Grafana, OTEL, cloudflared
│
├── apps/                          # All application source code
│   ├── catalog-api/               # Provides catalog data to UI and other services
│   ├── order-worker/              # Background processing for order side-effects
│   ├── orders-api/                # Handles carts and orders
│   └── shop-ui/                   # Browser UI for the whole flow
│
├── ops/                           # Operational and architectural documentation
│   ├── runbooks/                  # Operational runbooks, troubleshooting, SRE-style docs
│   └── docs/                      # Design notes, diagrams, planning material
│
├── k8s/                           # Kubernetes manifests and Helm charts
│   ├── apps/                      # Workload-level manifests (per service)
│   └── infra/                     # Infra add-ons managed via GitOps (Prometheus, Grafana, OTEL, ingress)
│
└── ci/                            # CI/CD pipeline definitions
    └── github/                    # GitHub Actions workflows and pipeline configs


## Phases

The project proceeds in well-defined phases. Each phase builds on the previous one.

- **Phase 0:** Repo structure, conventions, tooling
- **Phase 1:** Terraform provisioning of Azure core infrastructure (hub-spoke VNets, Firewall, ACR, private AKS, Key Vault, Postgres, Service Bus)
- **Phase 2:** Cluster add-ons, Workload Identity, Key Vault CSI, egress hardening, Log Analytics, Service Bus network rules, remote backend storage (all Terraform)
- **Phase 3:** Observability stack (Prometheus, Grafana, OTEL) via Kubernetes manifests
- **Phase 4:** Data and messaging integration (Postgres, Cosmos DB, Service Bus with Workload Identity)
- **Phase 5:** Ingress, TLS, and first demo app (NGINX Ingress, cert-manager, Let's Encrypt)
- **Phase 6:** Application services (TinyShop backend + Next.js UI)
- **Phase 7:** CI/CD with GitHub Actions + GitOps with ArgoCD
- **Phase 8:** Cloudflare Tunnel, WAF, and advanced topics (service mesh, Dapr, KEDA/event-driven autoscaling, node pool splitting)

Each phase has a clear checkpoint defining what must work before moving on.

## Conventions

- Containers follow 12-factor principles where practical.
- No Kubernetes Secrets for sensitive values; all secrets come from Key Vault.
- All workloads authenticate to Azure via Workload Identity.
- Only Cloudflare Tunnel provides ingress; no public load balancers.
- GitOps is the source of truth for cluster workloads.

## Who This Is For

Engineers and architects who want hands-on, realistic experience designing and operating cloud-native systems on Azure. Familiarity with Azure is assumed; AKS experience is not.

## Status

**Completed:**
- Phase 0: Repository structure and conventions 
- Phase 1: Azure core infrastructure via Terraform
  - Hub-spoke VNets with peering
  - Azure Firewall with UDR for egress control 
  - Private AKS cluster with Workload Identity enabled 
  - ACR, Key Vault, Postgres Flexible Server, Service Bus 
  - Private DNS zones and Private Endpoints 
  - Jump host for cluster access 
- Phase 2: Cluster add-ons and security plumbing 
  - Jump host, Workload Identity, Key Vault CSI, egress hardening, Log Analytics wiring 
- Phase 3: Observability stack (Prometheus, Grafana, OTEL Collector, Jaeger) 
  - NGINX Ingress for internal access, kube-prometheus-stack, OTEL Collector, Jaeger with internal DNS/Ingress 

**In Progress:**
- Phase 4: Data and messaging integration (Postgres, Cosmos DB, Service Bus with Workload Identity)
