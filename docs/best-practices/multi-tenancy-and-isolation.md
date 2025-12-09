# Multi-Tenancy & Isolation Best Practices

Checklist-style guidance for safely sharing AKS clusters across teams, applications, or tenants, while maintaining clear isolation boundaries.

---

## 1. Tenancy Model & Boundaries

- **Define your tenancy model explicitly (per-cluster, per-namespace, per-service)**  
  *Why*: Clarify which concerns are shared vs. isolated and avoid accidental cross-tenant coupling.

- **Use separate clusters for strong isolation requirements**  
  *Why*: Regulatory, security, or blast-radius constraints sometimes require hard boundaries only achievable with separate clusters.

- **Use namespaces for lighter-weight isolation within a cluster**  
  *Why*: Namespaces provide logical separation, policy scoping, and RBAC boundaries with less operational overhead than multiple clusters.

- **Group workloads by trust level and environment**  
  *Why*: Keep dev/test/prod and high-trust vs. low-trust tenants from sharing the same blast radius unnecessarily.

---

## 2. Namespaces & Resource Scoping

- **Create dedicated namespaces per team, application, or tenant as appropriate**  
  *Why*: Provide clear scoping for RBAC, NetworkPolicy, quotas, and observability.

- **Standardize namespace naming and labels (env, owner, tenant, data-classification)**  
  *Why*: Make it easy to apply policies and filters across many namespaces consistently.

- **Restrict cross-namespace access by default**  
  *Why*: Prevent one tenant or app from accidentally or maliciously interacting with another's resources.

- **Use namespace-scoped RoleBindings instead of cluster-wide ClusterRoleBindings where possible**  
  *Why*: Reduce the risk of over-privileged identities affecting multiple tenants.

---

## 3. RBAC & Access Isolation

- **Design RBAC roles around responsibilities (platform, app, read-only, CI/CD)**  
  *Why*: Align permissions with real-world roles and minimize accidental overreach.

- **Grant permissions at the smallest practical scope (namespace > cluster)**  
  *Why*: Contain the blast radius of misconfigurations or compromised credentials.

- **Avoid giving application service accounts cluster-admin or broad cluster roles**  
  *Why*: Application workloads should rarely need to interact with cluster-wide resources.

- **Use separate identities for CI/CD, operators, and applications**  
  *Why*: Improve auditing and constrain what each identity can change.

- **Audit RBAC policies and bindings regularly**  
  *Why*: Identify and remediate privilege creep and unused roles.

---

## 4. Network Isolation Between Tenants

- **Use NetworkPolicy to default-deny traffic between namespaces**  
  *Why*: Prevent lateral movement; only explicitly allowed cross-namespace communication should be possible.

- **Allow only required namespace-to-namespace traffic**  
  *Why*: Model explicit dependencies (e.g. gateway namespace to app namespaces) while keeping tenants separate.

- **Isolate shared infrastructure components (ingress, service mesh, monitoring) in dedicated namespaces**  
  *Why*: Apply stricter policies to cross-cutting components and prevent tenant workloads from interfering with them.

- **Consider separate ingress controllers per trust zone or tenant class**  
  *Why*: Reduce the impact of misconfiguration or compromise of a shared ingress on unrelated tenants.

---

## 5. Node Pools & Workload Placement

- **Use dedicated node pools for workloads with different trust or performance profiles**  
  *Why*: Isolate noisy or untrusted tenants and apply tailored scaling and security policies.

- **Use node selectors and taints/tolerations to control where pods can run**  
  *Why*: Prevent sensitive workloads from sharing nodes with untrusted or noisy neighbors.

- **Consider separate node pools for system, shared platform, and tenant workloads**  
  *Why*: Protect critical system components from tenant-driven resource exhaustion.

- **Use topology spread constraints within and across nodes/zones**  
  *Why*: Improve availability and reduce correlated failures for each tenant.

---

## 6. Resource Quotas & Fair-Sharing

- **Apply ResourceQuota per namespace or tenant**  
  *Why*: Prevent one tenant from consuming all cluster resources and impacting others.

- **Use LimitRange to enforce per-pod and per-container limits**  
  *Why*: Ensure each workload declares realistic resource usage and cannot exceed defined caps.

- **Monitor quota usage and adjust based on actual consumption and SLOs**  
  *Why*: Balance fairness with business priorities and avoid artificial throttling of critical services.

- **Expose usage and quota dashboards per tenant or team**  
  *Why*: Give tenants visibility into their own consumption and constraints.

---

## 7. Security Boundaries & Sensitive Tenants

- **Place highly sensitive or regulated tenants in dedicated clusters or node pools**  
  *Why*: Strengthen isolation and simplify compliance scoping.

- **Avoid co-locating untrusted and highly privileged workloads on the same nodes**  
  *Why*: Reduce the risk of container breakout impacting privileged components.

- **Use stricter Pod Security and admission policies for sensitive namespaces**  
  *Why*: Enforce more restrictive constraints on workloads handling sensitive data.

- **Review multi-tenancy choices with security and compliance stakeholders**  
  *Why*: Ensure isolation levels align with risk appetite and regulatory obligations.

---

## 8. Data Isolation & Access Control

- **Isolate tenant data at the storage and schema level**  
  *Why*: Make it easier to reason about which data belongs to which tenant and enforce boundaries.

- **Use per-tenant identities or authorization scopes for data access where practical**  
  *Why*: Allow fine-grained enforcement of which tenant can access which data.

- **Avoid shared database accounts across unrelated tenants**  
  *Why*: Reduce the risk that a compromise in one tenant grants access to another's data.

- **Enforce row- or column-level security when multi-tenant data sharing is required**  
  *Why*: Limit which records or fields each tenant can see without full data duplication.

---

## 9. Observability & Governance per Tenant

- **Partition logs and metrics logically by tenant, team, or namespace**  
  *Why*: Enable per-tenant dashboards, troubleshooting, and cost attribution.

- **Limit cross-tenant visibility in observability tools where required**  
  *Why*: Prevent tenants from viewing each other's data or operational details if that is a concern.

- **Provide self-service views and alerts for each tenant/team**  
  *Why*: Allow teams to own their reliability and performance while platform teams retain global visibility.

- **Audit cross-tenant interactions regularly**  
  *Why*: Detect unintended dependencies or violations of isolation policies.

---

## 10. Onboarding, Offboarding & Lifecycle

- **Standardize onboarding flows for new tenants or teams (namespaces, RBAC, quotas, NetworkPolicy)**  
  *Why*: Ensure new tenants are created with all required guardrails and consistency.

- **Automate teardown of tenants that are decommissioned**  
  *Why*: Remove unused namespaces, resources, and identities to reduce attack surface and cost.

- **Maintain clear ownership metadata for each tenant namespace and resource**  
  *Why*: Know who to contact for changes, incidents, and cost questions.

- **Review tenant configurations periodically against current best practices**  
  *Why*: Keep existing tenants aligned with evolving security and platform standards.

---

## 11. Design Principles for Multi-Tenancy

- **Prefer stronger isolation where uncertainty exists**  
  *Why*: When risk is unclear, err on the side of separate namespaces, node pools, or clusters.

- **Design for least surprise between tenants**  
  *Why*: Changes in one tenant should not unexpectedly affect others.

- **Make isolation explicit in code, config, and documentation**  
  *Why*: Reduce reliance on tribal knowledge and implicit assumptions.

- **Continuously evaluate whether current tenancy boundaries still fit reality**  
  *Why*: As systems and organizations evolve, revisit whether isolation lines remain appropriate.
