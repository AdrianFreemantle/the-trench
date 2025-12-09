# GitOps & Deployments Best Practices

Checklist-style guidance for GitOps, Flux, Argo CD, Kustomize, Helm, and deployment strategies in AKS.

---

## 1. GitOps Fundamentals

- **Understand GitOps: Git is the source of truth for desired cluster state**
  *Why*: All configuration (manifests, Helm releases, policies) lives in Git. The cluster continuously reconciles to match Git.

- **Prefer GitOps pull over CI/CD push for cluster state**
  *Why*: Push deployments require CI to have cluster credentials. Pull-based GitOps controllers run in-cluster and pull from Git.

- **Benefits of GitOps**:
  - **Auditability**: Git history shows who changed what, when
  - **Reproducibility**: Recreate any environment from Git
  - **Rollback**: Revert Git commit to roll back changes
  - **Security**: Cluster credentials stay in-cluster, not in CI pipelines

---

## 2. Flux vs Argo CD

- **Both are CNCF projects implementing GitOps; choose based on team needs**

- **Flux**:
  - Modular components (source-controller, kustomize-controller, helm-controller)
  - Kubernetes-native CRDs for everything
  - Better multi-tenancy with namespaced controllers
  - Tighter integration with Kustomize and Helm

- **Argo CD**:
  - Rich UI for visualization and management
  - Application-centric model
  - Good for teams wanting visual deployment management
  - Sync windows and waves for complex rollouts

- **Use Flux for infrastructure-heavy, multi-tenant platforms**
  *Why*: Its composable architecture fits platform engineering patterns.

- **Use Argo CD for application teams wanting visual deployment control**
  *Why*: The UI and application model are more accessible to developers.

---

## 3. How Flux Reconciles State

- **Source Controller watches Git repositories**
  *Why*: Polls or receives webhooks from Git, downloads manifests, creates Artifact objects.

- **Kustomize Controller applies Kustomization resources**
  *Why*: Takes source artifacts, runs Kustomize build, applies to cluster, reports status.

- **Helm Controller manages HelmRelease resources**
  *Why*: Installs/upgrades Helm charts from HelmRepository sources.

- **Reconciliation loop runs continuously (default 1-10 minutes)**
  *Why*: Detects drift between Git and cluster, automatically corrects. Manual sync available.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: platform
  path: ./k8s/overlays/dev
  prune: true
```

---

## 4. Kustomize Patterns for GitOps

- **Use a base + overlays structure for environment separation**
  *Why*: Base contains common manifests. Overlays patch for dev/staging/prod without duplication.

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    └── prod/
        ├── kustomization.yaml
        └── patch-replicas.yaml
```

- **Use strategic merge patches for small changes**
  *Why*: Override specific fields (replicas, resource limits) without copying entire manifests.

- **Use JSON patches for complex modifications**
  *Why*: Insert, remove, or replace at specific paths when strategic merge is insufficient.

- **Use Kustomize components for optional features**
  *Why*: Components can be included or excluded per environment (e.g., debug sidecars only in dev).

---

## 5. Per-Environment Separation in GitOps

- **Separate environments by directory path, not branch**
  *Why*: Branch-based GitOps is harder to manage (merge conflicts, divergence). Path-based keeps all environments in main branch.

- **Use overlays for environment-specific configuration**
  *Why*: Same base manifests, different patches for replicas, resources, secrets references, and feature flags.

- **Consider separate Git repositories for infrastructure vs applications**
  *Why*: Platform team owns infra repo (namespaces, policies, RBAC). App teams own app repos. Both sync independently.

- **Use Flux's Kustomization dependencies for ordering**
  *Why*: Ensure infrastructure (namespaces, CRDs) deploys before applications that depend on them.

```yaml
spec:
  dependsOn:
    - name: infrastructure
```

---

## 6. Helm in GitOps

- **Use HelmRelease CRDs instead of running helm install in CI**
  *Why*: Declarative Helm management with drift correction and automatic upgrades.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nginx-ingress
spec:
  interval: 1h
  chart:
    spec:
      chart: ingress-nginx
      version: "4.x"
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
  values:
    controller:
      replicaCount: 3
```

- **Pin chart versions explicitly**
  *Why*: Avoid unexpected upgrades. Use renovate or dependabot to propose version bumps as PRs.

- **Store values in Git, reference secrets from Key Vault**
  *Why*: Non-sensitive values in Git. Secrets via SOPS, Sealed Secrets, or external-secrets.

- **Use Helm's post-renderers for additional patching**
  *Why*: Apply Kustomize patches on top of Helm-rendered manifests for organization-specific requirements.

---

## 7. Managing Secrets in GitOps

- **Never commit plaintext secrets to Git**
  *Why*: Git history is permanent. Even deleted secrets remain in history.

- **Option 1: SOPS (Secrets OPerationS)**
  *Why*: Encrypts secrets in Git with age or Azure Key Vault keys. Flux decrypts at apply time.

- **Option 2: Sealed Secrets**
  *Why*: Encrypt secrets with cluster public key. Only the in-cluster controller can decrypt.

- **Option 3: External Secrets Operator**
  *Why*: Reference secrets stored in Key Vault; ESO syncs them as K8s Secrets.

- **Option 4: Secrets Store CSI Driver**
  *Why*: Mount secrets directly from Key Vault without creating K8s Secrets.

- **Choose based on workflow**: SOPS for GitOps-native encryption. ESO/CSI for centralized secret management.

---

## 8. Blue/Green Deployments on AKS

- **Deploy new version as separate Deployment, switch Service selector**
  *Why*: Both versions run simultaneously. Traffic switch is instant via selector change.

- **Use labels to distinguish versions**
  ```yaml
  # Blue deployment
  labels:
    app: api
    version: blue

  # Green deployment
  labels:
    app: api
    version: green

  # Service selector points to active version
  selector:
    app: api
    version: blue  # switch to green for cutover
  ```

- **Validate green deployment before switching**
  *Why*: Run smoke tests against green's ClusterIP before exposing to production traffic.

- **Keep blue running for quick rollback**
  *Why*: If green has issues, switch selector back to blue instantly.

- **Use Argo Rollouts or Flagger for automated blue/green**
  *Why*: These controllers manage the traffic switch based on analysis and metrics.

---

## 9. Canary Deployments

- **Route a percentage of traffic to new version, gradually increase**
  *Why*: Detect issues with minimal user impact before full rollout.

- **Use Flagger with Flux or Argo Rollouts**
  *Why*: Automated canary progression based on metrics (error rate, latency).

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: api
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
```

- **Define clear success criteria**
  *Why*: Error rate < 1%, p99 latency < 500ms, etc. Automated rollback on failure.

- **Use traffic splitting at ingress or service mesh level**
  *Why*: NGINX ingress canary annotations, Istio VirtualService, or Linkerd TrafficSplit.

---

## 10. Multi-Service Coordinated Releases

- **Use Flux dependencies to order releases**
  *Why*: Database migrations before API. Shared libraries before consumers.

- **Version APIs and support multiple versions during transitions**
  *Why*: Don't require lock-step deployment. Old and new consumers coexist.

- **Use feature flags for gradual feature rollout**
  *Why*: Deploy code without activating features. Enable progressively.

- **Coordinate breaking changes with expand-contract pattern**
  *Why*: Add new schema/API → migrate consumers → remove old schema/API.

---

## 11. Rollback Strategies

- **For GitOps: revert the Git commit**
  *Why*: Flux/Argo will reconcile to previous state. Clean audit trail.

- **For Helm: HelmRelease automatically tracks history**
  *Why*: Failed upgrades can trigger automatic rollback based on remediation settings.

```yaml
spec:
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
  rollback:
    cleanupOnFail: true
```

- **Keep sufficient replica history for quick Deployment rollback**
  *Why*: `kubectl rollout undo` works if ReplicaSets are retained.

- **Test rollback procedures regularly**
  *Why*: Don't learn rollback during an incident. Practice in staging.

---

## 12. Safely Rolling Out Breaking Schema Changes

- **Never deploy schema changes and code changes simultaneously**
  *Why*: If either fails, you can't tell which caused the issue.

- **Use expand-contract migrations**:
  1. **Expand**: Add new column/field (nullable or with default)
  2. **Deploy**: Code writes to both old and new, reads from new
  3. **Migrate**: Backfill existing data
  4. **Contract**: Remove old column/field after all consumers updated

- **Version your message schemas**
  *Why*: Queue consumers may receive old and new message formats during transition.

- **Test migrations against production-like data volumes**
  *Why*: A migration that works on dev may timeout on production data sizes.

---

## 13. Design Principles for GitOps

- **Git is the source of truth—no manual kubectl changes**
  *Why*: Manual changes cause drift and are not auditable. All changes through Git PRs.

- **Make deployments boring and repeatable**
  *Why*: Every deployment should be the same process. Special deployments are risky.

- **Separate what changes frequently from what doesn't**
  *Why*: Infrastructure (namespaces, RBAC) changes rarely. App images change often. Structure repos accordingly.

- **Embrace continuous reconciliation**
  *Why*: Don't just sync on commit. Continuous reconciliation catches manual drift and applies fixes.
