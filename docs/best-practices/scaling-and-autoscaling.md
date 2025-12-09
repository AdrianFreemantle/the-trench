# Scaling & Autoscaling Best Practices

Checklist-style guidance for HPA, KEDA, Cluster Autoscaler, backpressure, and capacity planning in AKS.

---

## 1. Understanding the Scaling Layers

- **Distinguish between pod scaling and node scaling**
  *Why*: HPA/KEDA scale pods within existing capacity. Cluster Autoscaler adds/removes nodes when pod demand exceeds/falls below node capacity.

- **Know the four scaling mechanisms and how they interact**
  - **HPA** (Horizontal Pod Autoscaler): Scales pods based on CPU, memory, or custom metrics
  - **KEDA** (Kubernetes Event-Driven Autoscaling): Scales pods based on external event sources (queues, streams)
  - **Cluster Autoscaler**: Adds/removes nodes based on pending pods or underutilized nodes
  - **Node autoscaling**: Azure-level VMSS scaling, usually managed by Cluster Autoscaler

- **Understand the scaling sequence**
  *Why*: When load increases: HPA/KEDA creates pods → pods go Pending if no capacity → Cluster Autoscaler provisions nodes → pods schedule. This takes 2-5 minutes.

---

## 2. Why CPU-Based HPA Is Often Insufficient

- **CPU is a lagging indicator for I/O-bound workloads**
  *Why*: A service waiting on database queries shows low CPU but high latency. Scaling on CPU won't help.

- **CPU doesn't reflect queue depth or backlog**
  *Why*: A worker processing a queue may have constant CPU but a growing backlog. CPU-based scaling won't catch up.

- **Request-based workloads need RPS or latency metrics**
  *Why*: Scale on requests-per-second or p99 latency to match actual demand, not CPU consumption.

- **Use CPU as a safety ceiling, not the primary trigger**
  *Why*: CPU limits can protect against runaway pods, but scale-out decisions should use business metrics.

---

## 3. KEDA for Event-Driven Scaling

- **Use KEDA for workloads driven by external event sources**
  *Why*: KEDA natively understands queue lengths, Kafka consumer lag, cron schedules, and 60+ other scalers.

- **Scale on queue depth for worker services**
  *Why*: If your Service Bus queue has 1000 messages and each pod processes 10/second, KEDA calculates the right replica count.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-worker
spec:
  scaleTargetRef:
    name: order-worker
  minReplicaCount: 1
  maxReplicaCount: 50
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: orders
        messageCount: "10"  # messages per replica
```

- **Configure Kafka lag-based scaling for stream processors**
  *Why*: Scale based on consumer group lag to keep processing caught up with producers.

- **Use KEDA's scale-to-zero capability thoughtfully**
  *Why*: Great for cost savings on dev/staging or batch jobs, but ensure startup time is acceptable and thundering herd is managed.

---

## 4. Configuring HPA Effectively

- **Set appropriate metrics for your workload type**
  *Why*: HTTP services scale on RPS or latency. Background processors scale on queue depth. Compute-intensive jobs scale on CPU.

- **Use multiple metrics with `behavior` controls**
  *Why*: Scale up quickly on demand, scale down slowly to avoid flapping.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

- **Set realistic minReplicas for availability**
  *Why*: At least 2 replicas for redundancy. Consider 3+ for zone-spread requirements.

- **Avoid maxReplicas that would overwhelm downstream systems**
  *Why*: 100 pods hitting a database simultaneously can cause more harm than good.

---

## 5. Cluster Autoscaler Configuration

- **Enable Cluster Autoscaler on user node pools**
  *Why*: Automatically provision nodes when pods are pending due to insufficient capacity.

- **Set appropriate min/max node counts**
  *Why*: Min ensures baseline capacity for fast scaling. Max prevents runaway costs.

- **Configure scale-down settings for cost optimization**
  *Why*: Nodes with low utilization can be removed, but too aggressive scaling causes churn.

- **Understand node provisioning time (2-5 minutes)**
  *Why*: Cluster Autoscaler is not instant. Plan for this latency in capacity planning.

- **Use multiple node pools for different workload profiles**
  *Why*: Separate pools for CPU-intensive, memory-intensive, and spot workloads allow targeted scaling.

---

## 6. What Happens When Node Pools Hit Max Capacity

- **Pods remain in Pending state with FailedScheduling events**
  *Why*: The scheduler cannot place pods when no node has sufficient resources and autoscaler is at max.

- **Design alerts for Pending pods and autoscaler-at-max conditions**
  *Why*: This is a critical signal that capacity planning failed. Investigate immediately.

- **Plan for N+1 or N+2 capacity headroom**
  *Why*: Always have room for at least one node failure plus some growth before hitting max.

- **Consider pre-provisioning for known traffic spikes**
  *Why*: Scale up nodes before an expected event (marketing campaign, release) rather than reacting.

---

## 7. Backpressure and Load Shedding

- **Implement backpressure at service boundaries**
  *Why*: When a service is overwhelmed, it should signal upstream to slow down rather than accepting unbounded load.

- **Use rate limiting to protect against traffic spikes**
  *Why*: Reject excess requests with 429 rather than degrading performance for all requests.

- **Implement load shedding when under sustained overload**
  *Why*: Dropping some requests (503) preserves quality for accepted requests and prevents cascade failures.

- **Use queue-based buffering for bursty workloads**
  *Why*: A queue absorbs traffic spikes and allows workers to process at sustainable rates.

---

## 8. SEDA (Staged Event-Driven Architecture) in AKS

- **Design multi-stage pipelines with queues between stages**
  *Why*: Each stage scales independently based on its own backlog, preventing bottleneck propagation.

- **Example SEDA pattern**:
  ```
  Ingress → API (fast ack) → Queue → Worker Stage 1 → Queue → Worker Stage 2 → Result Store
  ```
  *Why*: Each stage has its own scaling policy. API scales on RPS, workers scale on queue depth.

- **Use KEDA ScaledObjects for each worker stage**
  *Why*: Each stage monitors its input queue and scales accordingly.

- **Implement per-stage health checks and circuit breakers**
  *Why*: A failing downstream stage shouldn't bring down upstream stages.

---

## 9. Preventing Cascading Failures

- **Set timeouts on all outbound calls**
  *Why*: Prevent hung connections from consuming resources and causing caller exhaustion.

- **Use circuit breakers around unstable dependencies**
  *Why*: Fail fast when a downstream service is unhealthy, protecting your own resources.

- **Implement bulkheads to isolate failures**
  *Why*: Separate thread pools or connection pools for different dependencies prevent one slow service from affecting others.

- **Design retries with exponential backoff and jitter**
  *Why*: Avoid retry storms that amplify load on recovering services.

- **Consider hedged requests for critical paths**
  *Why*: Send duplicate requests to multiple backends, use first response. Improves tail latency at cost of resources.

---

## 10. Pod Disruption Budgets (PDBs)

- **Configure PDBs for all critical workloads**
  *Why*: Limit how many pods can be unavailable simultaneously during voluntary disruptions (upgrades, drains).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 2  # or use maxUnavailable: 1
  selector:
    matchLabels:
      app: api
```

- **Use minAvailable for services that need minimum capacity**
  *Why*: Ensures at least N pods always serve traffic during disruptions.

- **Use maxUnavailable for large deployments**
  *Why*: For 100 pods, `maxUnavailable: 10%` allows parallel draining without specifying exact counts.

- **Avoid overly restrictive PDBs that block upgrades**
  *Why*: `minAvailable: 100%` means nodes can never drain. Balance availability with operational needs.

---

## 11. Tuning Eviction and Drain Behavior

- **Configure terminationGracePeriodSeconds appropriately**
  *Why*: Give pods time to finish in-flight requests and shutdown cleanly. Default 30s may be too short for long requests.

- **Implement preStop hooks for graceful shutdown**
  *Why*: Use preStop to delay SIGTERM, allowing load balancers to drain connections.

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]
```

- **Handle SIGTERM in your application**
  *Why*: Stop accepting new requests, finish in-flight work, close connections, then exit.

- **Configure node drain timeout for batch workloads**
  *Why*: Long-running jobs may need extended drain time. Use pod-deletion-cost annotation for priority.

---

## 12. Capacity Planning Principles

- **Profile workloads to understand resource characteristics**
  *Why*: Know whether your service is CPU-bound, memory-bound, I/O-bound, or network-bound.

- **Size pods based on actual utilization, not guesses**
  *Why*: Review metrics to right-size requests and limits. Over-provisioned pods waste capacity.

- **Plan for the scaling lag (pod startup + node provisioning)**
  *Why*: Total time from demand spike to serving capacity can be 3-10 minutes. Account for this.

- **Model capacity under failure scenarios**
  *Why*: With N-1 nodes, can you still handle expected load? With 50% pods restarting?

- **Use synthetic load testing to validate scaling behavior**
  *Why*: Don't wait for production spikes to learn that autoscaling doesn't work as expected.

---

## 13. Design Principles for Scaling

- **Scale based on demand signals, not supply signals**
  *Why*: Scale on queue depth, request rate, or latency—not on CPU alone.

- **Design for scale-out, not scale-up**
  *Why*: Horizontal scaling with many small pods is more resilient than few large pods.

- **Assume autoscaling will lag behind demand**
  *Why*: Build buffers (queues, rate limits) to handle the gap between spike and scale-out.

- **Test scaling behavior regularly, not just in production**
  *Why*: Validate that scaling works as expected with load tests and chaos experiments.
