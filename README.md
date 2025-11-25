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
- Postgres Flexible Server (managed) + self-hosted MongoDB StatefulSet
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
│   ├── service-a/                 # Backend service 1
│   ├── service-b/                 # Backend service 2
│   └── ui/                        # Next.js frontend
│
├── ops/                           # Operational and architectural documentation
│   ├── adr/                       # Architecture Decision Records
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

1. **Phase 0:** Repo structure, conventions, tooling, ADR templates
2. **Phase 1:** Terraform provisioning of Azure core infrastructure
3. **Phase 2:** Cluster add-ons, Workload Identity, Key Vault CSI
4. **Phase 3:** Ingress via Cloudflare Tunnel + NGINX + TLS
5. **Phase 4:** Observability stack (Prometheus, Grafana, OTEL)
6. **Phase 5:** Data and messaging (Postgres, Mongo, Service Bus)
7. **Phase 6:** Application services and Next.js UI
8. **Phase 7:** CI/CD with GitHub Actions + GitOps with ArgoCD
9. **Phase 8:** Hardening and advanced topics
10. **Phase 9:** Documentation and teaching material

Each phase has a clear checkpoint defining what must work before moving on.

## Conventions

- Containers follow 12-factor principles where practical.
- No Kubernetes Secrets for sensitive values; all secrets come from Key Vault.
- All workloads authenticate to Azure via Workload Identity.
- Only Cloudflare Tunnel provides ingress; no public load balancers.
- Every significant decision is documented as an ADR.
- GitOps is the source of truth for cluster workloads.

## Who This Is For

Engineers and architects who want hands-on, realistic experience designing and operating cloud-native systems on Azure. Familiarity with Azure is assumed; AKS experience is not.

## Status

We are currently on **Phase 0**: repository setup, conventions, and initial documentation.
