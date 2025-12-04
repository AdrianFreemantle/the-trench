# AKS Scaling & Node Pool Strategy

This document captures the scaling and node pool design for the `trench-aks-cluster-dev` cluster in **southafricanorth**, along with how manifests and Helm values should be wired to use it.

## 1. Concepts

### 1.1 Node pools and VM Scale Sets (VMSS)

- Each **AKS node pool** is backed by a single **Azure VM Scale Set (VMSS)**.
- Scaling a node pool (up or down) changes the **number of VMs** in the VMSS.
- Node pools can be:
  - **System**: runs Kubernetes control-plane add-ons (CoreDNS, metrics-server, etc.).
  - **User**: runs workload pods (apps, platform services).

### 1.2 Horizontal scaling

Node pools support two models:

- **Manual scaling**
  - Set a fixed `node_count` (via Terraform or `az aks nodepool scale`).
- **Cluster autoscaler**
  - Enable `enable_auto_scaling = true`.
  - Configure `min_count` / `max_count`.
  - Autoscaler adds/removes nodes based on pending pods and utilization.

Example (conceptual):

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  vm_size        = "Standard_B2s"
  vnet_subnet_id = azurerm_subnet.spoke_aks_nodes.id
  mode           = "User"

  enable_auto_scaling = true
  min_count           = 1
  max_count           = 2
}
```

### 1.3 HA in Kubernetes

There are two main layers of high availability (HA):

- **Workload HA (Deployments/ReplicaSets)**
  - You set `spec.replicas` on a `Deployment`.
  - The scheduler **tries** to spread replicas across nodes if multiple nodes are available and have capacity.
  - For strict spreading you can add `podAntiAffinity` or `topologySpreadConstraints`.

- **Cluster / node-pool HA**
  - If you only have **one node** in a pool, all replicas of that pools workloads may end up on that node.
  - If that node dies, those pods are unavailable until the node is replaced.
  - With **multiple nodes** in the pool, the scheduler can place replicas on different nodes, and pods can be rescheduled to healthy nodes if one fails.

Effective HA therefore requires:

1. **`replicas > 1`** on the workload.
2. **`node_count > 1`** in the node pool(s) where it can run.

---

## 2. Size & quota considerations

- Region: `southafricanorth`.
- Minimum practical AKS node size for real workloads is **2 vCPU / 4 GiB RAM**.
- Cost/quota constraints are significant for this lab; the cluster is destroyed and recreated frequently.

Recommended VM sizes for this environment:

- **Standard_B2s**
  - 2 vCPU, 4 GiB RAM.
  - Burstable; good for **app workloads**.
- **Standard_D2s_v3** or **Standard_D2as_v5**
  - 2 vCPU, 8 GiB RAM.
  - Non-burst; better for **system and platform** workloads (more predictable CPU).

Subnet capacity check (current config):

- Spoke VNet: `10.1.0.0/16`.
- AKS nodes subnet: `10.1.0.0/24` (256 IPs).
- With Azure CNI and default `maxPods` (30), a design with up to 5 nodes fits comfortably.

---

## 3. Target node pool layout

The target design for `azurerm_kubernetes_cluster.aks`:

### 3.1 System pool (default_node_pool)

- **Name:** `system` (default)
- **Usage:** Cluster system components only.
- **VM size:** `Standard_D2as_v5` (or `Standard_D2s_v3` if that is the available family).
- **Node count:** `1`.
- **Mode:** System (via `default_node_pool`).
- **Scheduling:**
  - AKS automatically schedules system pods here.
  - Application and platform workloads are steered away via `nodeSelector` and/or dedicated user pools.

### 3.2 Apps pool (user workloads)

- **Resource:** `azurerm_kubernetes_cluster_node_pool.apps` (to be added).
- **Name:** `apps`.
- **Usage:** Application services such as `demo-api` and future business APIs.
- **VM size:** `Standard_B2s`.
- **Node count:**
  - Initial: `1`.
  - Later: use cluster autoscaler or manual scale to `2` when doing HA/failure labs.
- **Mode:** `User`.
- **Labels:**
  - `node_labels = { workload = "apps" }`.
- **Taints:** none (apps can freely schedule here).

### 3.3 Platform pool (observability + CI/CD)

- **Resource:** `azurerm_kubernetes_cluster_node_pool.platform` (to be added).
- **Name:** `platform`.
- **Usage:** Observability and GitOps components:
  - Prometheus + Grafana (kube-prometheus-stack).
  - OpenTelemetry Collector.
  - ArgoCD.
  - (Optionally) ingress-nginx, Loki, etc.
- **VM size:** `Standard_D2as_v5` / `Standard_D2s_v3`.
- **Node count:** `1` (initially; can scale to 2 later).
- **Mode:** `User`.
- **Labels:**
  - `node_labels = { workload = "platform" }`.
- **Taints (optional but recommended):**
  - `node_taints = ["platform=true:NoSchedule"]`.
  - Ensures only platform workloads (with a matching toleration) land here.

---

## 4. Manifest & Helm wiring

The node pool layout only takes effect if workloads explicitly target the intended pools.

### 4.1 App workloads (e.g. demo-api)

In `k8s/base/apps/demo-api/deployment.yaml` (and other app Deployments), add:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        workload: apps
```

This tells the scheduler: *only schedule this pod on nodes with label `workload=apps`* (i.e., the apps pool).

### 4.2 Platform workloads (Prometheus, Grafana, OTEL, ArgoCD, ingress-nginx)

In the Helm values under `k8s/infra/helm/`:

#### Example: ArgoCD (`argocd-values.yaml`)

For each component (controller, server, repoServer, redis):

```yaml
controller:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

server:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

repoServer:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

redis:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

#### Example: kube-prometheus-stack (`kube-prometheus-stack-values.yaml`)

```yaml
prometheus:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

grafana:
  nodeSelector:
    workload: platform
  tolerations:
    - key: "platform"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

#### Example: OTEL Collector (`opentelemetry-collector-values.yaml`)

Apply the same pattern under the Collectors pod template.

#### Example: ingress-nginx (`ingress-nginx-values.yaml`)

Set node selector and toleration for the Ingress controller pods so they run on the platform pool.

> With `nodeSelector` + `tolerations`, platform workloads are pinned to platform nodes and tolerated for the `platform=true:NoSchedule` taint.

---

## 5. Runbooks and workflows

The runbooks under `ops/runbooks/` do not need structural changes to support the new node pool layout:

- `ops/runbooks/deploy-observability-dev.sh`
- `ops/runbooks/deploy-argocd-dev.sh`

They continue to:

- Apply Kustomize overlays (for namespaces and ingress).
- Install Helm charts using the values files.

Because scheduling behavior is driven by the **Helm values** and **Deployment manifests**, updating those files as described above is sufficient.

---

## 6. Future evolution

Once quota and cost allow, the following changes will bring real HA characteristics:

- **Scale apps pool** to at least 2 nodes (via autoscaler or manual scale).
- **Scale platform pool** to 2 nodes if you require HA for observability and GitOps.
- Increase `replicas` on key Deployments (apps and platform services) so they can be spread across nodes.
- Optionally add `topologySpreadConstraints` or `podAntiAffinity` for stricter distribution across nodes.

For now, the design focuses on:

- Clean separation between **system**, **apps**, and **platform** workloads.
- Minimal but realistic node sizing per pool.
- Keeping the cluster small enough to fit within vCPU quota and cost constraints while still reflecting production-like patterns.
