# Trench AKS Security Roadmap

This is the security and identity roadmap for The Trench. This will be the focus once we have completed everything in the plan.md document.

Identity and PIM are manual and persistent. Everything else is rebuilt by Terraform and manifests.

---

## 0. High-level structure

1. Tenant level (manual, persistent)
   - Entra users and groups
   - PIM configuration for high-privilege roles and groups
2. Subscription level (Terraform “landing zone” or scripted)
   - Azure RBAC assignments for groups
   - Azure Policy definitions and assignments
3. Cluster level (Terraform + GitOps)
   - Namespaces and Kubernetes RBAC
   - Gatekeeper installation and constraints
   - Workload identities and CI/CD identities

---

## 1. Tenant: users and security groups (manual, one-time)

Create Entra security groups:

1. Core personas
   - `aks-cluster-admins`  
     - For cluster and platform break-glass ops
   - `aks-platform-ops`  
     - For day-to-day platform work, but not app ownership
   - `aks-dev-team-a`
   - `aks-dev-team-b`  
     - Simulate two product teams for multi-tenant behaviour
   - `aks-security-readonly`  
     - Security and compliance read-only access

2. System identities (tied to workload identities and CI/CD later)
   - `aks-gitops-argo-admin`  
     - For ArgoCD to talk to the cluster and ACR
   - `aks-ci-github-actions`  
     - For GitHub Actions deploy jobs
   - Optional: `aks-observability-agents`  
     - For Prometheus, OTEL Collector, etc, if they need Azure access

Create lab users (manual):

- `dev1@...` and `dev2@...` (add to `aks-dev-team-a`)
- `dev3@...` (add to `aks-dev-team-b`)
- `platform.ops@...` (add to `aks-platform-ops`)
- `sec.analyst@...` (add to `aks-security-readonly`)
- Your main “engineer” identity (add to one dev group, platform ops, and cluster admins)

Document group membership explicitly in a markdown file in the repo, for your own reference:

- `ops/identity/personas.md`

---

## 2. Tenant: PIM design and configuration (manual)

Define which roles are permanent vs eligible:

1. Permanent roles
   - `aks-dev-team-a`, `aks-dev-team-b`
     - No PIM. They always have dev / test rights at cluster level, but no cluster admin.
   - `aks-security-readonly`
     - Always-on Reader rights in Azure and view-only in K8s.
   - `aks-ci-github-actions`, `aks-gitops-argo-admin`
     - Service identities. No PIM.

2. PIM eligible roles
   - `aks-cluster-admins`
     - Eligible for:
       - Subscription or RG Contributor
       - AKS Cluster Admin Role (or equivalent) on the AKS resource
     - Time bound: 1 or 2 hours
     - Justification required
     - Optional approval from a second account
   - Optional: `aks-platform-ops`
     - Permanent: Contributor on some RGs (dev, shared)
     - Eligible: Contributor or higher on prod RG or prod AKS

Configure PIM (manual in portal):

- Make `aks-cluster-admins` eligible for:
  - `Owner` or `Contributor` at subscription or AKS RG
  - Or the `Azure Kubernetes Service RBAC Cluster Admin` role on the AKS resource
- Require:
  - Justification text
  - Reasonable activation duration (max 2 hours)
- Turn on email notifications for PIM activations for your own awareness.

Document PIM rules in `ops/identity/pim-policy.md`.

---

## 3. Subscription: Azure RBAC assignments (Terraform or script)

Use Terraform or Azure CLI scripts to assign roles to groups at scope.

For each AKS cluster (or lab subscription):

1. At subscription or resource group scope:
   - `aks-cluster-admins`
     - Role: `Contributor` on the AKS resource group and node resource group
   - `aks-platform-ops`
     - Role: `Contributor` on:
       - AKS RG
       - Data RG (Postgres, Service Bus, Cosmos) for non prod
   - `aks-security-readonly`
     - Role: `Reader` at subscription or AKS RG

2. At AKS resource scope:
   - `aks-dev-team-a`
     - Role: `Azure Kubernetes Service RBAC Cluster User` or `Reader`
   - `aks-dev-team-b`
     - Same as team A
   - `aks-gitops-argo-admin`
     - Role: `Azure Kubernetes Service RBAC Cluster Admin` or `Cluster User` plus K8s RBAC bound in cluster
   - `aks-ci-github-actions`
     - Role: `Azure Kubernetes Service RBAC Cluster User` on AKS
     - Role: `AcrPush` on ACR

All of the above should be defined in Terraform in a “landing zone” module:

- `infra/terraform/subscription-rbac/`  
  - `rbac.tf` that binds group object IDs to roles

Group object IDs are looked up via `data "azuread_group"` or similar.

---

## 4. Subscription: Azure Policy baseline for AKS (Terraform)

Define a minimal but realistic set of policies, attached at subscription or AKS RG scope.

1. AKS security posture policies (built-in where possible)
   - Require private AKS:
     - Deny clusters with public API enabled
   - Require managed identity:
     - Deny AKS clusters that use service principals
   - Require RBAC:
     - Deny AKS clusters with RBAC disabled
   - Require local account disabled:
     - Deny clusters that allow local admin account kubeconfig
   - Require diagnostic settings:
     - `DeployIfNotExists`:
       - AKS must send logs and metrics to Log Analytics
   - Defender for Kubernetes:
     - `DeployIfNotExists` or `AuditIfNotExists` for Defender plan enablement

2. Network and egress related policies
   - Require Azure CNI network plugin
   - Require network policy enabled (Calico or Cilium, depending on your choice)
   - Optional: deny AKS clusters in disallowed regions

3. Assignment strategy
   - For “lab” subscription:
     - Initially set critical ones to `Audit` to see violations
     - Once stable, switch to `Deny` for:
       - public API
       - service principal auth
       - RBAC disabled
       - local account enabled

Implement in Terraform:

- `infra/terraform/policy/`
  - `definitions.tf` for any custom policy definitions
  - `assignments.tf` to bind policies to subscription

Document the policy set in `ops/security/azure-policy-baseline.md`.

---

## 5. Cluster: namespace model and Kubernetes RBAC (YAML + Terraform)

Define namespaces that match your personas and phases:

1. System and infra namespaces
   - `kube-system` (AKS internal)
   - `ingress-system` (NGINX / ingress controller)
   - `cert-manager`
   - `observability-system` (Prometheus, Grafana, OTEL)
   - `gatekeeper-system`
   - `argocd`
   - `platform-system` (other platform operators, CSI drivers etc)

2. Application namespaces
   - `tinyshop-dev-team-a`
   - `tinyshop-test-team-a`
   - `tinyshop-dev-team-b` (even if you only have one app, use this to simulate)
   - Later: `tinyshop-prod-*` when you introduce prod

Implement as:

- Terraform for namespaces (via Kubernetes provider)
- ArgoCD or plain manifests for RBAC bindings

Kubernetes RBAC bindings:

1. Cluster wide
   - ClusterRoleBinding `aks-cluster-admins`:
     - Group: `aks-cluster-admins` → `cluster-admin`
   - ClusterRoleBinding `aks-security-view`:
     - Group: `aks-security-readonly` → `view`

2. Namespace scoped for dev teams
   - RoleBinding in `tinyshop-dev-team-a` and `tinyshop-test-team-a`:
     - Group: `aks-dev-team-a` → `admin` or `edit` ClusterRole
   - Same pattern for Team B in their namespaces

3. System identities
   - RoleBinding in `argocd`:
     - Group: `aks-gitops-argo-admin` → `admin` in `argocd`
   - ClusterRoleBinding or limited bindings so ArgoCD can manage target namespaces:
     - Use a `ClusterRole` with the exact verbs and resources Argo needs
   - RoleBinding in application namespaces for `aks-ci-github-actions` if pipelines use kubectl directly

Store all RBAC YAML in:

- `k8s/base/rbac/`
  - `cluster-admins.yaml`
  - `security-view.yaml`
  - `team-a-namespace-rbac.yaml`
  - `team-b-namespace-rbac.yaml`
  - `argo-rbac.yaml`
  - `ci-rbac.yaml`

Apply them via ArgoCD as part of the bootstrap or via Terraform using `kubernetes_manifest`.

---

## 6. Cluster: Gatekeeper installation

Use Gatekeeper as your admission control engine.

1. Install Gatekeeper
   - Deploy into `gatekeeper-system` namespace
   - Use Helm or official manifests
   - Wire this into your cluster bootstrap:
     - Terraform Helm release
     - Or ArgoCD app-of-apps pattern

2. Basic configuration
   - Set audit interval and webhook failure policy to a reasonable value
   - Decide if you want:
     - `fail-closed` (deny on webhook issues) for prod posture
     - Or `fail-open` in early lab stages

Document Gatekeeper installation and version in:

- `ops/security/gatekeeper-install.md`

---

## 7. Cluster: Gatekeeper constraint set (essential policies)

Define a minimal but serious baseline of constraints. Implement as ConstraintTemplates and Constraints in version controlled YAML.

1. Pod security constraints
   - `no-privileged-containers`
     - Block `securityContext.privileged = true`
   - `block-host-network-pid-ipc`
     - Deny Pods that set `hostNetwork`, `hostPID`, or `hostIPC` to true
   - `block-host-path-volumes`
     - Deny use of `hostPath` volumes
   - `no-run-as-root`
     - Require `runAsNonRoot: true`
     - Optionally require `runAsUser` not equal to 0

2. Resource constraints
   - `require-cpu-mem-limits`
     - Require `resources.requests` and `resources.limits` for CPU and memory on all containers
   - Optional stricter version:
     - Enforce a maximum CPU and memory limit per container in non system namespaces

3. Image and registry constraints
   - `restrict-image-registries`
     - Only allow images from:
       - your ACR
       - optional public registries you explicitly whitelist (for lab tooling)
   - `disallow-latest-tag`
     - Warn or deny use of `:latest` tag on images

4. Metadata and multi-tenancy constraints
   - `require-namespace-owner-label`
     - Namespaces must have labels:
       - `owner` = `team-a` or `team-b` or `platform`
       - `environment` = `dev` or `test` or `prod`
   - `require-app-labels`
     - Pods and Deployments must include:
       - `app`
       - `component`
       - `team`

5. Ingress and network constraints
   - `enforce-tls-on-ingress`
     - Ingress must:
       - Have `tls` section configured
       - Have annotations for cert-manager or note your Cloudflare tunnel model
   - Optional: `block-nodeport-services`
     - Deny creation of `NodePort` services outside dedicated infra namespaces

6. Gradual enforcement strategy
   - Phase 1:
     - Set all constraints to `enforcementAction: dryrun`
     - Observe violations in Gatekeeper audit
   - Phase 2:
     - Switch high impact security constraints (no privileged, no root, no hostPath) to `deny`
   - Phase 3:
     - Switch resource limits and image policies to `deny`
   - Phase 4:
     - Consider environment specific strictness:
       - dev: some policies `dryrun`
       - prod: all essential policies `deny`

Store all Gatekeeper artifacts under:

- `k8s/base/gatekeeper/`
  - `constrainttemplates/`
  - `constraints/`

Bootstrap them via ArgoCD in Phase 2 or 3.

---

## 8. CI/CD, workload identity, and separation of duties

Tie identities and policies back into the Trench phases.

1. Workload identity mapping
   - For each service that needs Azure access (Postgres, Service Bus, Cosmos):
     - Create a user-assigned managed identity
     - Map it to a Kubernetes service account using Workload Identity
     - Give that identity minimal Azure roles:
       - `db_datareader` or similar roles on Postgres
       - `Azure Service Bus Data Sender` / `Receiver`
       - `Cosmos DB Account Reader` or scoped roles

2. CI/CD identities
   - `aks-ci-github-actions`
     - GitHub OIDC trust set up to assume this identity
     - Has:
       - ACR push rights
       - AKS Cluster User role
     - Deployment steps authenticate as this identity
   - `aks-gitops-argo-admin`
     - Pod identity in `argocd` namespace bound to this group or managed identity
     - Has K8s and ACR rights required to sync manifests but no Azure broad rights

3. Separation of duties
   - Devs:
     - Can deploy to `tinyshop-dev-team-*` namespaces via PR merge and CI
   - Platform ops:
     - Maintain Gatekeeper constraints, ArgoCD, ingress, CSI, network policies
   - Cluster admins:
     - Only used with PIM for:
       - Cluster upgrades
       - CNI changes
       - Gatekeeper emergency changes
   - Security:
     - Have read-only access to:
       - Azure resources (Policy, Defender)
       - K8s resources (pods, events, Gatekeeper reports)

Document the model in:

- `ops/security/separation-of-duties.md`

---

## 9. Validation and test scenarios

Define explicit tests to verify the model is working:

1. RBAC tests
   - As `dev1` in `aks-dev-team-a`:
     - Deploy to `tinyshop-dev-team-a` (should succeed)
     - Deploy to `tinyshop-dev-team-b` (should be forbidden)
     - List pods in `kube-system` (should be forbidden)
   - As `sec.analyst`:
     - `kubectl get pods -A` (should work read-only)
     - `kubectl delete pod` anywhere (should be forbidden)
   - As `platform.ops`:
     - Manage deployments in `ingress-system` and `observability-system`
     - No rights in `tinyshop-*` namespaces if you choose strict variant

2. PIM tests
   - Try to upgrade AKS or modify node pools without PIM (should be forbidden)
   - Activate PIM for `aks-cluster-admins`
   - Retry upgrade (should succeed)
   - After PIM expiry, confirm loss of rights

3. Azure Policy tests
   - Attempt to create a public AKS cluster in the lab subscription
     - Should be denied by policy
   - Attempt to create AKS with service principal
     - Should be denied

4. Gatekeeper tests
   - Deploy pod without resource limits (should be denied after you enforce)
   - Deploy pod with `runAsUser: 0` (should be denied)
   - Deploy pod using image from non whitelisted registry (should be denied)
   - Deploy Ingress without TLS (denied or audited, depending on policy)

Document test steps and expected results in:

- `ops/security/validation-checklist.md`

---

## 10. Integration into Trench phases

Thread this roadmap into your existing phases:

- Phase 1
  - Private AKS, managed identity, basic RBAC groups and Azure RBAC assignments
  - Azure Policy baseline for AKS posture (at least `Audit`)
- Phase 2
  - Namespaces and K8s RBAC personas
  - Gatekeeper installation
- Phase 3
  - Add observability namespaces and RBAC
  - Gatekeeper `dryrun` constraints
- Phase 4
  - Workload identities and minimal data access roles
- Phase 5
  - Ingress policies and Gatekeeper ingress constraints
- Phase 6
  - Enforce critical Gatekeeper constraints for app namespaces
- Phase 7
  - CI/CD identities and ArgoCD / GitHub Actions rights
- Phase 8
  - Cloudflare, WAF rules integrated with the same persona model

This roadmap is the canonical checklist. Next step is to pick section 1 or 2 and start implementing it concretely in Terraform and YAML.
