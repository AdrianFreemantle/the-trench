# Hands-On AKS Experience Checklist

The list of applied learning objectives to build real operational intuition.

---

# 0. Setup & Baseline Environment

## 0.1 Terraform & Repo Setup
- [X] Create the repo structure for infra/ and k8s/
- [X] Install Terraform, kubectl, Flux CLI, Azure CLI
- [X] Create Azure service principal or use your identity for initial provisioning

---

# 1. Core Terraform & AKS Provisioning

### 1.1 VNet + Subnets 
- [X] Generate Terraform VNet + subnets (hub + AKS)
- [X] Apply and confirm VNet/subnets exist

### 1.2 AKS Cluster Creation 
- [X] Generate Terraform for AKS cluster 
- [X] Review OIDC, RBAC, network_profile, and outbound_type settings
- [X] Apply Terraform and confirm AKS cluster is up
- [X] Connect via `az aks get-credentials` (non-prod only)

---

# 2. Kubernetes Essentials 

### 2.1 Deployment + Service + Ingress
- [ ] Write one Deployment YAML (labels, probes, resources)
- [ ] Write matching Service YAML (selector correctness)
- [ ] Write Ingress YAML pointing to service
- [ ] Apply and confirm end-to-end traffic flow

### 2.2 NetworkPolicy
- [ ] Create a namespace
- [ ] Apply a default-deny ingress + egress NetworkPolicy
- [ ] Add explicit allow rules for:
  - [ ] DNS (UDP/TCP 53 to kube-dns)
  - [ ] Ingress → app traffic
  - [ ] App → Postgres
  - [ ] App → Service Bus
- [ ] Validate blocking/allowing using curl + nslookup

### 2.3 ArgoCD Application + Kustomization
- [ ] Write `infra/k8s/base/service-a/deployment.yaml`
- [ ] Write `infra/k8s/overlays/dev/kustomization.yaml`
- [ ] Install ArgoCD in the cluster
- [ ] Create ArgoCD Application pointing to the Git path
- [ ] Watch ArgoCD sync and reconcile

### 2.4 Key Vault CSI Binding
- [ ] Write SecretProviderClass YAML
- [ ] Mount secrets into pod as files or environment variables
- [ ] Validate secret access from pod using Workload Identity

### 2.5 Complete Workload Identity Path 
- [ ] Create AAD Workload Identity components
- [ ] Configure federated credential for the service account
- [ ] Annotate pod with workload identity info
- [ ] Validate Key Vault access from pod using WI

---

# 3. Observability Foundation (OTel Collector, Metrics, Logs, Traces)

### 3.1 OTel Collector Deployment
- [X] Deploy OTel Collector 
- [ ] Configure:
  - [X] OTLP receiver
  - [C] Prometheus receiver/scraper
  - [ ] Logs receiver (filelog or stdout)
  - [ ] Jaeger exporter OR console exporter
- [ ] Deploy a sample app and confirm:
  - [ ] Metrics visible in Prometheus
  - [ ] Traces visible in Jaeger
  - [ ] Logs flowing to log backend (or stdout)

### 3.2 SLO Setup
- [ ] Instrument 1–2 routes with RED metrics
- [ ] Build Grafana dashboard:
  - [ ] Request rate
  - [ ] Error rate
  - [ ] Latency p95/p99
- [ ] Create one SLO:
  - [ ] success_rate >= 99.9%
- [ ] Configure slow + fast burn alerts (PromQL templates)
- [ ] Validate by temporarily breaking the route

---

# 4. PaaS Integration (SQL, Cosmos, Service Bus)

### 4.1 Terraform PaaS Provisioning
- [X] Postgres Flexible Server (private endpoint)
- [X] Cosmos DB account (private endpoint)
- [X] Service Bus 
- [C] Key Vault
- [C] Private DNS zones + links

### 4.2 Application Integration
- [ ] App → Postgres via private DNS
- [ ] App → Cosmos DB via private DNS
- [ ] App → Service Bus via private DNS
- [ ] Verify connections from pod using curl + tcpping or equivalent

---

# 5. Network Hardening Labs

### 5.1 NetworkPolicy Default Deny in Namespace
- [ ] Apply default-deny NP
- [ ] App stops resolving DNS
- [ ] Fix by adding DNS allow

### 5.2 Private DNS Mapping Issues
- [ ] Temporarily remove Private DNS link
- [ ] App fails to resolve SQL/ServiceBus hostnames
- [ ] Re-add and verify fix

### 5.3 Firewall / Egress Rules
- [ ] Temporarily block egress to:
  - [ ] ACR
  - [ ] Service Bus
  - [ ] Postgres
- [ ] Reapply rules and validate pod recovery

---

# 6. Failure Labs 

### 6.1 Pod Pending Scenarios
- [ ] Over-high CPU/memory requests → Pending
- [ ] Wrong nodeSelector/affinity → Pending
- [ ] Taint mismatch → Pending
- [ ] PVC cannot bind due to wrong StorageClass → Pending

### 6.2 Pod Running but Not Ready / Non-responsive
- [ ] Break readiness probe path
- [ ] Break probe port
- [ ] Introduce slow backend (DB delay)
- [ ] Validate no endpoints in Service during readiness failures

### 6.3 Service / Endpoint Failures
- [ ] Change Service selector to not match pods → Endpoints=0
- [ ] Observe 503/504 from ingress
- [ ] Fix selector and validate readiness

### 6.4 DNS Failure Scenarios
- [ ] Block UDP 53 using NetworkPolicy
- [ ] Break Private DNS zone link
- [ ] Validate nslookup failures and retry logic

### 6.5 Egress Block Failures
- [ ] Block Service Bus egress → message send fails
- [ ] Block ACR egress → ImagePullBackOff
- [ ] Restore and validate recovery

---

# 7. GitOps Failure & Recovery Labs

### 7.1 Good Rollout
- [ ] Deploy v1 of catalog-api via ArgoCD
- [ ] Validate pod health and SLOs

### 7.2 Bad Rollout
- [ ] Update image tag to v2 with broken readiness
- [ ] ArgoCD syncs and applies it
- [ ] SLOs degrade

### 7.3 GitOps Rollback
- [ ] `git revert` commit to return to v1
- [ ] ArgoCD syncs and restores health

### 7.4 Drift Correction
- [ ] Manually scale Deployment to wrong replica count
- [ ] ArgoCD detects drift and reverts it automatically (if self-heal enabled)

---

# 8. HPA + Scaling + Connection Storm Lab

### 8.1 Add HPA
- [ ] Configure HPA on API service

### 8.2 Generate Traffic
- [ ] Use bombardier/hey from a running pod
- [ ] Observe HPA scale-out

### 8.3 Trigger DB saturation scenario
- [ ] Overwhelm DB with concurrent requests
- [ ] Watch:
  - [ ] DB connection saturation
  - [ ] App latency spikes
  - [ ] HPA runaway scaling effects

### 8.4 Apply fixes
- [ ] Limit per-pod connection pool
- [ ] Add retry-with-jitter
- [ ] Reduce HPA max replicas
- [ ] Validate stability improvement

---
