# AKS Reliability, HA & Scalability Best Practices

Checklist-style guidance for high availability, fault tolerance, resilience, and scalability in AKS, structured from the outside in.

---

## 1. Architecture & Topology

- **Design for failure domains (regions, zones, node pools)**  
  *Why*: Limit blast radius when a region, zone, or node pool fails; keep critical services available.

- **Use Availability Zones where supported for AKS and data services**  
  *Why*: Protect against single-zone outages by spreading control plane and nodes across zones.

- **Separate system and user node pools**  
  *Why*: Prevent user workloads from starving system components (kube-system, ingress, CNI, DNS) and vice versa.

- **Isolate workloads with different SLOs into dedicated node pools**  
  *Why*: Apply tailored autoscaling, node SKUs, and disruption policies for latency-critical vs. batch workloads.

- **Co-locate data and compute in the same region**  
  *Why*: Reduce latency and avoid cross-region dependencies that can break under network partitions.

---

## 2. Ingress, Traffic Management & DNS

- **Use a highly available ingress layer (multiple replicas, zonal spread)**  
  *Why*: Ensure external traffic can still be routed when individual nodes/zones fail.

- **Configure health checks and timeouts on load balancers and ingress**  
  *Why*: Quickly detect unhealthy backends and avoid sending traffic to failing pods.

- **Use DNS with low, but sane, TTLs**  
  *Why*: Allow endpoints to move (e.g. failovers, blue/green) without long DNS caching delays.

- **Avoid single points of ingress for critical systems**  
  *Why*: Where appropriate, use multiple ingress controllers or failover paths to avoid a single ingress controller outage taking down access.

---

## 3. Deployment Strategies & Rollouts

- **Use rolling updates (not Recreate) for Deployments**  
  *Why*: Maintain a portion of pods serving traffic while new versions roll out.

- **Configure RollingUpdate with `maxUnavailable` and `maxSurge` for SLOs**  
  *Why*: Control how many pods can be down and how many can surge to balance availability vs. rollout speed.

- **Set `revisionHistoryLimit` for Deployments**  
  *Why*: Keep a manageable number of older ReplicaSets for quick rollback without cluttering the cluster.

- **Use pod health probes (liveness, readiness, startup) correctly**  
  *Why*: Ensure only healthy pods receive traffic and stuck pods are restarted.

- **Adopt progressive delivery patterns for critical services**  
  *Why*: Use canary or blue/green to reduce risk from new releases and rollback quickly on issues.

---

## 4. Replication, Pod Availability & Disruptions

- **Configure appropriate replica counts per service**  
  *Why*: Ensure enough pods to handle failures and load; avoid single-pod Deployments for critical paths.

- **Spread pods across nodes and zones using topology spread constraints**  
  *Why*: Avoid concentration of all replicas on one node/zone; reduce correlated failure impact.

- **Use PodDisruptionBudgets for critical workloads**  
  *Why*: Limit how many pods can be taken down simultaneously by voluntary disruptions (drains, upgrades).

- **Set node autoscaler and cluster autoscaler correctly**  
  *Why*: Scale node pools up and down automatically to meet demand while avoiding capacity starvation.

- **Avoid anti-patterns that break scaling (e.g. sticky node affinity without reason)**  
  *Why*: Allow the scheduler to place pods flexibly to achieve higher availability and better bin-packing.

---

## 5. Resilient Application Design

- **Implement timeouts for all outbound calls**  
  *Why*: Prevent hung connections from exhausting resources and causing cascading failures.

- **Use retries with backoff and jitter for transient failures**  
  *Why*: Increase success rates under brief outages while avoiding retry storms.

- **Apply circuit breakers around unstable dependencies**  
  *Why*: Fail fast when a downstream service is unhealthy, protecting your own service and upstream callers.

- **Apply rate limiting at service and client boundaries**  
  *Why*: Prevent individual clients or upstreams from overwhelming a service; ensure capacity is shared fairly and predictably.

- **Use load shedding when under sustained overload**  
  *Why*: Prefer rejecting or degrading some requests (e.g. returning 429/503) over allowing the entire service to collapse under load.

- **Implement backpressure for queues and async workloads**  
  *Why*: Slow or throttle producers when consumers are overloaded, using signals like queue depth and processing latency to avoid unbounded backlog growth.

- **Use bulkheads and isolation between critical and non-critical functionality**  
  *Why*: Prevent failures in low-priority features from impacting core business flows.

- **Return graceful degradation responses where possible**  
  *Why*: Preserve partial functionality (e.g. cached data, simplified responses) instead of total failure.

- **Design idempotent operations and safe retries**  
  *Why*: Ensure retries do not cause duplicate side-effects, especially in message processing and write APIs.

- **Handle graceful shutdown and pod termination signals correctly**  
  *Why*: Allow in-flight requests to complete and background work to finish or checkpoint before pods are removed from service.

---

## 6. State, Data & Storage Resilience

- **Choose managed, highly available data stores (e.g. zone-redundant Postgres, Cosmos DB)**  
  *Why*: Offload replication, failover, and patching to managed services with built-in SLAs.

- **Use appropriate consistency and replication options per data store**  
  *Why*: Balance latency, durability, and availability for each workload.

- **Design for database failover / connection string changes**  
  *Why*: Support planned and unplanned failovers with minimal downtime (e.g. using DNS aliases or failover groups).

- **Separate read and write workloads where beneficial**  
  *Why*: Use read replicas or caching to offload reads and protect the primary DB during traffic spikes.

- **Implement caching (per-service or shared) for read-heavy data**  
  *Why*: Reduce load on databases, decrease latency, and improve resilience when DB is slow.

- **Backup data and test restores regularly**  
  *Why*: Ensure that data can be recovered after corruption, operator error, or catastrophic failures.

---

## 7. Autoscaling & Capacity Management

- **Enable Horizontal Pod Autoscaler (HPA) for scalable services**  
  *Why*: Automatically adjust pod counts based on CPU/memory/custom metrics to match workload.

- **Use Cluster Autoscaler for node pools**  
  *Why*: Add/remove nodes dynamically as pod demand changes, reducing cost while maintaining capacity.

- **Base autoscaling on meaningful metrics, not just CPU**  
  *Why*: For many services, QPS, latency, or work queue depth are better indicators than CPU alone.

- **Set sensible resource requests/limits to support accurate scheduling**  
  *Why*: Allow the scheduler and autoscalers to make correct decisions about capacity and placement.

- **Plan for peak and failure scenarios (N+1, N+2 capacity)**  
  *Why*: Ensure the system can handle peak load even with one or more nodes or replicas down.

---

## 8. Failure Testing & Chaos Engineering

- **Regularly test pod-level failures (kill pods, simulate crashes)**  
  *Why*: Validate liveness/readiness probes, PDBs, and rollout behavior under real failure scenarios.

- **Test node-level failures (cordon/drain, node reboot, node deletion)**  
  *Why*: Ensure workloads reschedule correctly and that capacity and disruption budgets behave as expected.

- **Simulate dependency failures (DB down, external API slow/unavailable)**  
  *Why*: Confirm that timeouts, retries, and circuit breakers work and that applications degrade gracefully.

- **Run chaos experiments in lower environments before production**  
  *Why*: Build confidence that resilience patterns are effective and avoid surprises in production.

- **Automate some resilience tests as part of CI/CD or periodic jobs**  
  *Why*: Continuously verify that new changes have not weakened fault tolerance.

---

## 9. Observability, SLOs & Incident Management

- **Define SLOs and SLIs for key services (availability, latency, error rate)**  
  *Why*: Provide clear targets and signals for whether the system is meeting reliability goals.

- **Instrument applications with structured logs, metrics, and traces**  
  *Why*: Enable quick diagnosis of issues across services, including performance bottlenecks.

- **Create dashboards aligned with SLOs**  
  *Why*: Give operators and developers a shared view of system health.

- **Set alerts on symptoms, not just causes**  
  *Why*: Alert when users are impacted (e.g. high 5xx rate, elevated latency) rather than only on low-level metrics.

- **Run post-incident reviews and track action items**  
  *Why*: Learn from outages, fix root causes, and prevent recurrence or reduce impact.

---

## 10. Operational Practices & Process

- **Use GitOps or declarative config for infrastructure and workloads**  
  *Why*: Ensure environments are reproducible, changes are auditable, and rollbacks are straightforward.

- **Roll out changes gradually and during safe windows**  
  *Why*: Reduce user impact from unexpected failures, with staff available to respond.

- **Automate common remediation actions where safe**  
  *Why*: Reduce MTTR by automating restarts, failovers, or traffic shifts for known failure modes.

- **Document runbooks for common failure scenarios**  
  *Why*: Provide operators with clear steps to diagnose and mitigate, reducing human error under pressure.

- **Train teams on failure modes and resilience patterns**  
  *Why*: Ensure developers and operators design and operate services with reliability in mind from the start.

---

## 11. Design Principles for Reliable Systems

- **Expect and embrace failure**  
  *Why*: Design assuming components will fail (nodes, pods, networks, dependencies) and plan safe responses.

- **Design for graceful degradation**  
  *Why*: Prefer partial functionality over total outage when dependencies are impaired.

- **Favor loose coupling and bounded contexts**  
  *Why*: Reduce the chance of cascading failures when one service is overloaded or down.

- **Prefer idempotent, retriable operations and at-least-once semantics**  
  *Why*: Make failure recovery and replay safe without corrupting state.

- **Continuously measure and refine reliability**  
  *Why*: Use SLOs, incidents, and experiments to iteratively harden the system over time.
