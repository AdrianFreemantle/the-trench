# AKS Architecture Fundamentals

Checklist-style guidance on AKS architecture, control plane, data plane, strategic decisions, and when (not) to use AKS.

---

## 1. Control Plane vs Data Plane

### Control Plane (Azure-Managed)
- **API Server**: Receives all kubectl commands and API requests
- **etcd**: Stores all cluster state (objects, configs, secrets)
- **Controller Manager**: Runs controllers (Deployment, ReplicaSet, Node, etc.)
- **Scheduler**: Assigns pods to nodes based on constraints and resources
- **Cloud Controller Manager**: Integrates with Azure (load balancers, disks, routes)

*Why this matters*: You don't manage these components directly. Azure handles upgrades, scaling, and availability. But you need to understand them to diagnose issues.

### Data Plane (Customer-Managed Nodes)
- **Kubelet**: Agent on each node; manages pod lifecycle
- **Container Runtime**: containerd runs containers
- **Kube-proxy**: Network proxy for Service routing (iptables/IPVS)
- **CNI Plugin**: Azure CNI or kubenet for pod networking
- **CoreDNS**: Cluster DNS for service discovery
- **Your workloads**: Pods running your applications

*Why this matters*: You manage node pools, scaling, and workload placement. Node-level issues affect your pods directly.

---

## 2. What Runs Where

### kube-system Namespace (System Components)
- **coredns**: DNS resolution for cluster services
- **coredns-autoscaler**: Scales CoreDNS based on node/pod count
- **konnectivity-agent**: Secure tunnel from control plane to nodes
- **metrics-server**: Provides metrics for HPA and `kubectl top`
- **azure-ip-masq-agent**: NAT for pod egress
- **cloud-node-manager**: Node lifecycle management
- **csi-azuredisk-node**: Azure Disk CSI driver
- **csi-azurefile-node**: Azure Files CSI driver

### System Node Pool
- **Purpose**: Run critical system workloads separate from user workloads
- **Best practice**: Taint system pool, tolerate only system pods
- **Why**: Prevent user workloads from starving system components

### User Node Pools
- **Purpose**: Run application workloads
- **Best practice**: Multiple pools for different workload profiles (CPU, memory, GPU, spot)

---

## 3. Control Plane Upgrade Process

- **Step 1**: Azure upgrades control plane components (API server, etcd, controllers)
  - Brief API server unavailability (seconds to minutes)
  - Existing workloads continue running

- **Step 2**: Node pools upgraded separately (manually or auto)
  - Nodes cordoned and drained one at a time
  - Pods rescheduled to other nodes
  - New node provisioned with new version
  - Old node deleted

- **Key points**:
  - Control plane and node pools can be at different versions (within skew policy)
  - Plan for PDB compatibility during node drains
  - Test upgrades in staging first—API deprecations break workloads

---

## 4. API Server Saturation

### Symptoms
- Slow kubectl responses
- Webhook timeouts
- Controller reconciliation delays
- 429 (Too Many Requests) errors

### Causes
- Too many watches (large clusters, many controllers)
- Excessive LIST operations without pagination
- Chatty operators or controllers
- Large objects in etcd (big ConfigMaps, Secrets)

### Diagnosis
```bash
# Check API server metrics (if exposed)
kubectl get --raw /metrics | grep apiserver_request

# Check for slow requests in audit logs
# Look for high latency requests in Azure Monitor
```

### Mitigation
- Use informers with shared caches, not direct API calls
- Paginate LIST operations
- Reduce watch cardinality (fewer broad watches)
- Consider API Priority and Fairness settings
- For very large clusters, consider multiple clusters

---

## 5. etcd Pressure

### What etcd stores
- All Kubernetes objects (Deployments, Pods, ConfigMaps, Secrets, CRDs)
- Resource versions and watch state
- Lease information for leader election

### Symptoms of etcd pressure
- Slow cluster operations
- "etcdserver: request timed out" errors
- Leader election failures
- Cluster instability

### Causes
- Too many objects (>100k objects stress etcd)
- Large objects (ConfigMaps > 1MB)
- High write rate (frequent status updates)
- Large CRD populations

### Mitigation (within AKS constraints)
- Clean up unused resources (completed Jobs, old ReplicaSets)
- Avoid storing large data in ConfigMaps/Secrets
- Use external storage for large configs
- Reduce CRD cardinality where possible
- Set `revisionHistoryLimit` on Deployments

*Note*: In AKS, etcd is managed by Azure. You can't directly tune it, but you can reduce pressure through good practices.

---

## 6. When NOT to Use AKS

### Choose App Service Instead When:
- **Simple web apps** with standard scaling needs
- **Small teams** without Kubernetes expertise
- **Rapid time-to-market** is priority over flexibility
- **Cost sensitivity** for low-traffic apps (AKS has base cost)
- **Managed SSL, domains, and deployment slots** are sufficient

### Choose Azure Functions Instead When:
- **Event-driven, short-lived** workloads
- **Sporadic traffic** with long idle periods
- **Per-execution billing** makes more sense than always-on
- **Simple integrations** with Azure services (triggers, bindings)
- **No container orchestration** expertise on team

### Choose Container Apps Instead When:
- **Serverless containers** without Kubernetes complexity
- **KEDA-based scaling** without managing KEDA yourself
- **Dapr integration** for microservices patterns
- **Simpler networking** requirements

### Signals You Need AKS:
- Complex multi-service architectures requiring fine-grained control
- Custom operators or controllers
- Specific CNI or networking requirements
- Multi-tenant isolation requirements
- Team has Kubernetes expertise and operational capacity
- Workloads don't fit PaaS constraints

---

## 7. AKS vs PaaS Decision Framework

| Factor | Favor AKS | Favor PaaS |
|--------|-----------|------------|
| Team expertise | Strong K8s skills | Limited K8s skills |
| Operational capacity | Can manage clusters | Want managed everything |
| Workload complexity | Many services, custom patterns | Simple web/API/functions |
| Scaling needs | Complex, event-driven, custom | Standard CPU/memory based |
| Networking | Custom CNI, service mesh, policies | Standard load balancing |
| Portability | Multi-cloud, hybrid | Azure-native is fine |
| Cost model | Predictable baseline + scale | Pay-per-use preferred |
| Time to production | Can invest in platform | Need fast delivery |

### The Platform Burden Question
*"How much are you willing to invest in platform engineering?"*

- **Low investment**: Use PaaS (App Service, Functions, Container Apps)
- **Medium investment**: Use AKS with managed add-ons, GitOps, minimal customization
- **High investment**: Use AKS with custom operators, service mesh, advanced networking

---

## 8. Multi-Region AKS vs Single-Region + DR

### Choose Multi-Region Active-Active When:
- **Global users** requiring low latency in multiple regions
- **Regulatory requirements** for data residency
- **Zero RPO** requirements (no data loss acceptable)
- **High availability** SLOs (99.99%+)

### Choose Single-Region + DR (Passive) When:
- **Users concentrated** in one geography
- **Cost constraints** (active-active doubles infrastructure)
- **RTO/RPO flexibility** (hours acceptable, not minutes)
- **Simpler operations** preferred over maximum availability

### Multi-Region Complexity Costs:
- Database geo-replication and conflict resolution
- Global load balancing (Front Door, Traffic Manager)
- Cross-region data synchronization
- More complex CI/CD and GitOps
- Higher operational expertise required

---

## 9. Cluster Sizing and When to Split

### Signs Your Cluster Is Too Large:
- API server latency increasing
- etcd size approaching limits
- Upgrade windows too long/risky
- Blast radius of issues too large
- Team coordination across cluster becoming difficult

### Signs You Have Too Many Clusters:
- High operational overhead managing many clusters
- Duplicated effort in cluster configuration
- Inconsistent configurations across clusters
- Underutilized capacity in each cluster

### Splitting Strategies:
- **By environment**: Separate dev/staging/prod clusters
- **By team/domain**: Each team owns their cluster
- **By criticality**: Critical workloads isolated from experimental
- **By compliance**: Regulated workloads in dedicated cluster

### Rough Sizing Guidelines:
- **Small**: < 50 nodes, < 1000 pods
- **Medium**: 50-200 nodes, 1000-5000 pods
- **Large**: 200-1000 nodes, 5000-15000 pods
- **Very large**: Consider splitting or dedicated support

---

## 10. Node Pool Design

### System Node Pool
```bash
# Recommended configuration
az aks nodepool add \
  --mode System \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --node-taints CriticalAddonsOnly=true:NoSchedule
```
*Why*: Dedicated capacity for system components, protected from user workload pressure.

### User Node Pools by Workload Type

**General Purpose (APIs, web)**:
- Standard_D4s_v3 or Standard_D8s_v3
- Balanced CPU/memory ratio

**Memory-Intensive (caches, in-memory processing)**:
- Standard_E4s_v3 or Standard_E8s_v3
- Higher memory-to-CPU ratio

**CPU-Intensive (compute, ML inference)**:
- Standard_F4s_v2 or Standard_F8s_v2
- Higher CPU-to-memory ratio

**Spot Nodes (batch, fault-tolerant)**:
- Any SKU with spot pricing
- Use for interruptible workloads only

**GPU (ML training, inference)**:
- Standard_NC series
- Dedicated pool with GPU taints

---

## 11. Ephemeral OS Disks

### What They Are
- OS disk stored on node's local NVMe/SSD
- Faster boot times, lower latency
- Lost on node reimage/replacement

### When to Use
- **Stateless workloads** that don't rely on local node state
- **Performance-sensitive** applications needing fast disk I/O
- **Cost optimization** (no separate OS disk charges)

### When NOT to Use
- Workloads that store state on the OS disk (don't do this anyway)
- Debugging scenarios requiring node persistence

### Configuration
```bash
az aks nodepool add \
  --node-osdisk-type Ephemeral \
  --node-osdisk-size 100
```

---

## 12. Windows and Linux Mixed Clusters

### Use Cases
- .NET Framework applications (Windows-only)
- Mixed workload portfolios during migration
- Specific Windows dependencies

### Operational Considerations
- **Separate node pools**: Windows and Linux cannot share pools
- **Node selectors required**: Explicitly schedule to correct OS
- **Different networking**: Windows has some CNI limitations
- **Update cadence**: Windows nodes have different update schedules
- **Container images**: Separate builds for Windows vs Linux

### Best Practice
```yaml
# Always specify node selector for cross-platform clusters
nodeSelector:
  kubernetes.io/os: linux  # or windows
```

---

## 13. Private Clusters

### What Private Cluster Means
- API server has no public IP
- API server accessible only via private endpoint
- Requires VPN, ExpressRoute, or bastion for kubectl access

### When to Use
- **Security requirements** mandate no public endpoints
- **Compliance** (PCI, HIPAA, etc.)
- **Enterprise networks** with private connectivity

### Operational Impact
- CI/CD must run from within network or use self-hosted agents
- Developer access requires VPN or jump box
- More complex initial setup

### Alternative: API Server Authorized IP Ranges
- Keep public endpoint but restrict to specific IPs
- Simpler than full private cluster
- Suitable when public endpoint is acceptable with controls

---

## 14. Design Principles for AKS Architecture

- **Right-size for your team, not just your workload**
  *Why*: A complex setup your team can't operate is worse than a simpler one they can.

- **Start simple, add complexity when justified**
  *Why*: Don't add service mesh, custom CNI, and multi-region on day one.

- **Match cluster boundaries to organizational boundaries**
  *Why*: Teams that can operate independently should have independent clusters.

- **Plan for Day 2 operations from Day 1**
  *Why*: Upgrades, scaling, and troubleshooting should be considered upfront.

- **Use managed services where operational burden outweighs control benefits**
  *Why*: Running your own Kafka/Redis/Postgres in AKS is harder than using Azure managed services.
