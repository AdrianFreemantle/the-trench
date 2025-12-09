# Storage & Stateful Workloads Best Practices

Checklist-style guidance for storage options, stateful workloads, and data access patterns in AKS.

---

## 1. Azure Storage Options Comparison

### Azure Disks
- **Use for**: Single-pod stateful workloads (databases, single-writer apps)
- **Characteristics**: Block storage, attached to one node at a time, zone-bound
- **Performance tiers**: Standard HDD, Standard SSD, Premium SSD, Ultra Disk
- **Limitations**: Cannot be shared across pods; pod must be on same node as disk

### Azure Files
- **Use for**: Shared storage across multiple pods (shared config, uploads)
- **Characteristics**: SMB/NFS file shares, mountable by multiple pods
- **Performance tiers**: Standard, Premium
- **Limitations**: Higher latency than disks; NFS requires Premium tier

### Ephemeral Storage (emptyDir)
- **Use for**: Temporary scratch space, caching, inter-container sharing
- **Characteristics**: Node-local, lost when pod is evicted or rescheduled
- **Limitations**: Not persistent; size limited by node disk

### Ephemeral OS Disks
- **Use for**: Stateless node pools where local disk performance matters
- **Characteristics**: OS disk uses node's local SSD, faster boot, lower cost
- **Limitations**: All local state lost on node reimage; only for stateless workloads

---

## 2. When to Use Each Storage Type

- **Database single-primary**: Azure Disk (Premium SSD or Ultra for high IOPS)
- **Database with managed service**: Use Azure Database for PostgreSQL/MySQL instead of running in AKS
- **Log aggregation, file uploads**: Azure Files (Premium NFS for performance)
- **Cache, temp files**: emptyDir with memory or SSD backing
- **Container image layers**: Ephemeral OS disk for faster image pulls

- **Design principle**: Prefer managed PaaS databases over running databases in AKS unless you have strong operational expertise.

---

## 3. Node Affinity for Azure Disk Workloads

- **Problem**: Azure Disks are zone-bound and can only attach to nodes in the same zone
  *Why*: If a StatefulSet pod reschedules to a different zone, the disk cannot follow.

- **Solution 1: Use zone-aware storage class**
  ```yaml
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: managed-premium-zrs
  provisioner: disk.csi.azure.com
  parameters:
    skuName: Premium_ZRS  # Zone-redundant storage
  ```
  *Why*: ZRS disks can attach to nodes in any zone within the region.

- **Solution 2: Use topology constraints in StatefulSet**
  *Why*: Ensure pods schedule in the same zone as their existing PVCs.

- **Solution 3: Use Azure Files for cross-zone access**
  *Why*: Files shares are not zone-bound and can be mounted from any node.

---

## 4. Running Stateful Systems in AKS (When It's a Bad Idea)

- **Databases (Postgres, MySQL, SQL Server)**
  - **Bad idea when**: You lack DBA expertise, need HA/failover, or handle production-critical data
  - **Better alternative**: Azure Database for PostgreSQL Flexible Server, Azure SQL
  - **Acceptable when**: Dev/test environments, spike/cache databases, or you have dedicated DB operators

- **Message Brokers (Kafka, RabbitMQ)**
  - **Bad idea when**: You need guaranteed durability, complex partitioning, or production SLAs
  - **Better alternative**: Azure Service Bus, Azure Event Hubs, Confluent Cloud
  - **Acceptable when**: Dev/test, or you have dedicated Kafka/messaging expertise

- **Redis**
  - **Bad idea when**: You need persistence, clustering, or HA
  - **Better alternative**: Azure Cache for Redis
  - **Acceptable when**: Ephemeral cache only, no persistence required

- **Design principle**: Managed services trade control for operational burden. Most teams underestimate the ops cost of running stateful systems.

---

## 5. Connection Pooling and Storms

- **Problem**: When pods scale out, each new pod opens connections to databases
  *Why*: 50 pods × 20 connections each = 1000 connections overwhelming the database.

- **Solution 1: Use connection pooling inside the application**
  - .NET: Use `Npgsql` with pooling enabled (default), tune `MaxPoolSize`
  - Python: Use `SQLAlchemy` with pool configuration
  *Why*: Reuse connections within each pod; don't open new connections per request.

- **Solution 2: Use external connection pooling (PgBouncer, ProxySQL)**
  *Why*: Aggregate connections from many pods into fewer database connections.

- **Solution 3: Set aggressive idle connection timeouts**
  *Why*: Close unused connections quickly to free database resources.

- **Solution 4: Use connection limits per pod**
  *Why*: Cap the maximum connections each pod can open, regardless of load.

---

## 6. Connection String and Failover Handling

- **Use DNS-based connection strings, not IP addresses**
  *Why*: DNS can be updated during failover; IPs require application restart.

- **For Azure SQL/Postgres Flexible Server, use the failover-aware endpoint**
  *Why*: Azure manages DNS updates during failover automatically.

- **Configure connection retry logic**
  *Why*: During failover, connections fail briefly. Retry with backoff.

- **Test failover behavior in staging**
  *Why*: Verify your application handles failover gracefully without manual intervention.

---

## 7. Diagnosing IOPS Bottlenecks

- **Symptoms**: High disk latency, application timeouts, slow queries

- **Check disk IOPS limits**
  ```bash
  kubectl top pods  # CPU/memory
  kubectl describe pvc <pvc-name>  # storage class, size
  ```
  *Why*: Each Azure Disk tier has IOPS limits. P10 (128 GiB) = 500 IOPS, P30 (1 TiB) = 5000 IOPS.

- **Use Azure Monitor for disk metrics**
  *Why*: Track disk queue depth, latency, and throughput in Azure portal.

- **Solutions**:
  - Upgrade disk tier (P30 → P40)
  - Use Premium SSD v2 or Ultra Disk for high IOPS
  - Optimize queries to reduce I/O
  - Add caching layer (Redis) for reads

---

## 8. Consistency and Correctness for Stateful Handlers

- **Design for idempotency**
  *Why*: Message processors may receive duplicates due to at-least-once delivery. Processing the same message twice should be safe.

- **Use idempotency keys**
  *Why*: Track processed message IDs to detect and skip duplicates.

- **Handle ordering carefully**
  *Why*: Distributed queues may deliver messages out of order. Use sequence numbers or design for order-independence.

- **Use transactions or sagas for multi-step operations**
  *Why*: Ensure all-or-nothing semantics for operations spanning multiple resources.

- **Implement optimistic concurrency**
  *Why*: Use version fields or ETags to detect concurrent modifications and handle conflicts.

---

## 9. Private Link for Data Access

- **Use Private Endpoints for all Azure PaaS data services**
  *Why*: Traffic stays on Azure backbone, no public internet exposure.

- **Configure Private DNS zones for name resolution**
  *Why*: `mydb.postgres.database.azure.com` resolves to private IP, not public.

- **Disable public access on data services**
  *Why*: With Private Endpoint, there's no need for public network access.

- **Services supporting Private Endpoint**: SQL, PostgreSQL, MySQL, Cosmos DB, Storage, Key Vault, Service Bus, Event Hubs, Redis

---

## 10. Stateful Workload Patterns in Kubernetes

### StatefulSet
- **Use for**: Databases, message brokers, apps needing stable identity
- **Features**: Stable pod names (pod-0, pod-1), stable storage (PVC per pod), ordered startup/shutdown

### Deployment with PVC
- **Use for**: Single-instance stateful apps where ordering doesn't matter
- **Limitation**: If using Azure Disk, pod must schedule in same zone

### Operator-Managed (e.g., CloudNativePG, Strimzi)
- **Use for**: Production-grade databases with automated failover, backup, scaling
- **Benefits**: Operators encode DBA expertise in automation

---

## 11. Backup and Recovery

- **For Azure Disks**: Use Azure Disk snapshots or Azure Backup
  *Why*: Point-in-time recovery without application-level backup tooling.

- **For databases in AKS**: Use application-consistent backups (pg_dump, mysqldump)
  *Why*: Disk snapshots may capture inconsistent state if taken during writes.

- **For managed databases**: Use Azure's built-in backup/PITR
  *Why*: Azure handles backup scheduling, retention, and recovery.

- **Test restores regularly**
  *Why*: Backups are worthless if you can't restore from them.

---

## 12. Zero-Trust Data Access

- **Authenticate with managed identity, not connection strings with passwords**
  *Why*: No secrets to manage, rotate, or leak. Identity-based access.

- **Use row-level security in databases**
  *Why*: Enforce data access policies at the database level, not just application.

- **Encrypt data at rest (enabled by default in Azure)**
  *Why*: Protects data if storage is accessed outside normal paths.

- **Encrypt data in transit (TLS)**
  *Why*: Prevent eavesdropping on database connections.

- **Audit data access**
  *Why*: Log who accessed what data, when. Required for compliance.

---

## 13. Design Principles for Stateful Workloads

- **Prefer managed services for production stateful workloads**
  *Why*: Azure handles HA, backups, patching, and failover. You handle application logic.

- **Design applications to tolerate storage latency**
  *Why*: Network-attached storage is slower than local SSD. Optimize for I/O patterns.

- **Separate compute from storage concerns**
  *Why*: Stateless pods can scale freely. Stateful concerns are handled by external services.

- **Plan for data migration and evolution**
  *Why*: Schema changes, data migrations, and storage tier changes are inevitable.

- **Monitor storage metrics alongside application metrics**
  *Why*: Disk latency and throughput directly impact application performance.
