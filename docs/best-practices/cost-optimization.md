# AKS Cost & Efficiency Best Practices

Checklist-style guidance for designing and operating AKS and workloads cost-effectively, without sacrificing reliability.

---

## 1. Architecture & Environment Strategy

- **Right-size the number of clusters and environments**  
  *Why*: Too many clusters increase fixed costs and operational overhead; too few can harm isolation and governance.

- **Use a clear environment model (dev/test/stage/prod) with purpose**  
  *Why*: Avoid "snowflake" environments that are rarely used but continually billed.

- **Consolidate low-criticality workloads into shared clusters**  
  *Why*: Improve bin-packing and utilization while keeping strict isolation only where it is required.

- **Plan for capacity with N+1 or N+2 in mind, not N+10**  
  *Why*: Provide headroom for failures and peaks without massively overprovisioning.

---

## 2. Node Pools, SKUs & Scaling

- **Pick node SKUs that match workload characteristics**  
  *Why*: CPU-heavy, memory-heavy, and GPU workloads benefit from different SKUs; wrong SKUs waste money.

- **Separate system and user node pools**  
  *Why*: Right-size system nodes for control-plane add-ons and allow user pools to scale independently.

- **Use Cluster Autoscaler on user node pools**  
  *Why*: Automatically add/remove nodes based on pending pods, reducing idle capacity.

- **Use multiple node pools for distinct workload types**  
  *Why*: Apply different autoscaling, SKUs, and disruption policies to batch, real-time, and background jobs.

- **Consider spot/low-priority nodes for non-critical workloads**  
  *Why*: Take advantage of cheaper capacity for fault-tolerant, interruptible jobs.

- **Leverage reserved instances / savings plans for baseline capacity**  
  *Why*: Reduce cost for predictable, always-on parts of the cluster.

---

## 3. Pod Sizing, Bin-Packing & Autoscaling

- **Set realistic resource requests and limits for all containers**  
  *Why*: Accurate requests improve bin-packing, reduce wasted capacity, and make autoscaling effective.

- **Regularly review actual usage vs. requests (rightsizing)**  
  *Why*: Adjust over time as workloads evolve; free up headroom or prevent throttling.

- **Use Horizontal Pod Autoscaler (HPA) for scalable services**  
  *Why*: Scale pods up and down with demand instead of running for peak 24/7.

- **Avoid single-large pods where many smaller pods would scale better**  
  *Why*: Finer-grained pods improve bin-packing and fault isolation.

- **Avoid unbounded concurrency inside a pod**  
  *Why*: Match concurrency and throughput to available resources rather than overloading a single container.

---

## 4. Storage, Data & Retention

- **Choose storage classes and performance tiers based on real needs**  
  *Why*: Premium SSDs/Snapshots are expensive; use them only where latency and IOPS justify the cost.

- **Set retention policies for logs, metrics, and traces**  
  *Why*: Long retention dramatically increases storage costs; keep only what is useful for operations, audits, and compliance.

- **Clean up unused PersistentVolumeClaims and disks**  
  *Why*: PVCs and orphaned disks linger and continue to incur costs after workloads are gone.

- **Archive cold data to cheaper storage tiers or services**  
  *Why*: Move infrequently accessed data to lower-cost storage where feasible.

- **Avoid over-indexing and excessive metrics cardinality**  
  *Why*: Overly detailed metrics and logs drive up storage and query costs without proportional benefit.

---

## 5. Network, Egress & Edge Costs

- **Minimize cross-region traffic and avoid unnecessary data transfer**  
  *Why*: Inter-region and egress traffic can be a major hidden cost driver.

- **Use Private Endpoints within the same region where possible**  
  *Why*: Reduce egress charges and latency to Azure PaaS services.

- **Control outbound internet access with egress policies and firewalls**  
  *Why*: Prevent accidental or excessive calls to external services that generate data transfer and service costs.

- **Cache data close to where it is consumed**  
  *Why*: Reduce repeated remote calls and associated bandwidth and service costs.

---

## 6. Observability Cost Management

- **Log at appropriate levels and avoid debug logs in production by default**  
  *Why*: Logging is often a top cost driver; noisy logs add little value but large bills.

- **Sample traces and high-volume events**  
  *Why*: Full tracing for 100% of traffic is often unnecessary; sample intelligently to capture high-value cases.

- **Use tiered retention for observability data**  
  *Why*: Keep recent data hot and detailed; move older data to cheaper or summarized forms.

- **Consolidate observability tooling where it makes sense**  
  *Why*: Reduce licensing and operational overhead of many overlapping tools.

---

## 7. CI/CD, Environments & Lifecycle Management

- **Automate teardown of ephemeral environments (PR, feature, test)**  
  *Why*: Prevent forgotten test environments from running indefinitely and incurring costs.

- **Use smaller, cheaper environments for non-production where appropriate**  
  *Why*: Mirror functionality, not scale; reduce capacity and resource classes in lower environments.

- **Limit long-running integration tests or jobs on expensive SKUs**  
  *Why*: Use cost-effective compute for CI where possible, reserving high-end resources for necessary cases.

- **Enforce TTLs or cleanup policies for temporary resources (namespaces, jobs, PVs)**  
  *Why*: Avoid resource and cost buildup from abandoned artifacts.

---

## 8. Governance, Tagging & Cost Visibility

- **Tag Azure resources with owner, environment, application, and cost center**  
  *Why*: Enable chargeback/showback, accountability, and better cost attribution.

- **Expose cost dashboards per team and per application**  
  *Why*: Make cost visible to the people who can influence it; support informed trade-off decisions.

- **Set budgets and alerts at subscription, RG, and/or namespace levels**  
  *Why*: Detect runaway costs early and trigger investigation or automatic mitigations.

- **Use policies to prevent obviously wasteful configurations**  
  *Why*: Block creation of extremely large SKUs, unneeded public IPs, or overprovisioned resources by default.

---

## 9. Application Design for Efficiency

- **Optimize application performance to do less work per request**  
  *Why*: Faster, more efficient code uses fewer CPU and memory resources for the same throughput.

- **Use efficient protocols and payloads (e.g. gRPC, compressed JSON)**  
  *Why*: Reduce bandwidth, serialization overhead, and latency.

- **Implement caching and batching where appropriate**  
  *Why*: Lower the number of external calls and DB queries, improving both cost and performance.

- **Avoid chatty, fine-grained service calls when a coarse-grained API would suffice**  
  *Why*: Reduce network overhead and the number of billable operations.

---

## 10. Purchasing & Licensing Considerations

- **Leverage reserved capacity and savings plans for steady-state workloads**  
  *Why*: Commit to baseline usage to gain significant discounts over pay-as-you-go.

- **Review licenses and add-ons regularly**  
  *Why*: Disable or downgrade unused or underutilized premium features.

- **Align scaling policies with billing granularity**  
  *Why*: Consider how resources are billed (per minute/hour, per GB, per operation) when designing autoscaling and batch schedules.

---

## 11. Culture & Continuous Optimization

- **Make cost a shared responsibility across teams**  
  *Why*: Encourage developers, SREs, and platform teams to collaborate on cost-efficient designs.

- **Include cost reviews in architecture and design discussions**  
  *Why*: Catch expensive patterns early, before they become entrenched.

- **Run periodic cost optimization reviews and implement findings**  
  *Why*: Regularly identify and retire waste as workloads and usage patterns change.

- **Treat cost regressions like performance or reliability regressions**  
  *Why*: Create feedback loops so cost issues are visible and prioritized when they materially impact budgets.
