# Distributed Systems Fundamentals for AKS

Checklist-style guidance on distributed systems theory as it applies to microservices running on AKS.

---

## 1. CAP Theorem and AKS

- **Understand CAP tradeoffs for multi-region systems**
  - **Consistency**: All nodes see the same data at the same time
  - **Availability**: Every request receives a response
  - **Partition Tolerance**: System continues despite network partitions
  *Why*: You can only guarantee two of three. Network partitions are inevitable, so you choose between C and A.

- **For most AKS microservices, choose AP (Availability + Partition Tolerance)**
  *Why*: Prefer returning stale data or accepting writes optimistically over refusing requests.

- **For financial/critical data, choose CP (Consistency + Partition Tolerance)**
  *Why*: Prefer rejecting requests over returning inconsistent data.

- **Practical implication**: During a region failover, decide whether to:
  - Reject writes until consistency is confirmed (CP)
  - Accept writes with eventual reconciliation (AP)

---

## 2. Consistency Models

- **Strong consistency**: Reads always return the most recent write
  *Why*: Simplest to reason about but limits scalability and availability.

- **Eventual consistency**: Reads may return stale data, but will eventually be consistent
  *Why*: Enables higher availability and performance; requires application to handle stale reads.

- **Causal consistency**: Related events are seen in order; unrelated events may vary
  *Why*: Good balance for many applications; preserves logical ordering without global synchronization.

- **Design applications to tolerate eventual consistency where possible**
  *Why*: Most UIs can handle slight staleness (user sees their own writes).

---

## 3. Idempotency

- **Design all mutating operations to be idempotent**
  *Why*: In distributed systems, requests may be delivered more than once due to retries, network issues, or failover.

- **Use idempotency keys for writes**:
  ```csharp
  public async Task ProcessOrderAsync(string idempotencyKey, Order order)
  {
      if (await _db.ExistsAsync(idempotencyKey))
          return; // Already processed

      await _db.SaveOrderAsync(order);
      await _db.MarkProcessedAsync(idempotencyKey);
  }
  ```
  *Why*: Processing the same request twice produces the same result.

- **Store idempotency state persistently**
  *Why*: Memory-only state is lost on pod restart, defeating idempotency.

- **Set TTL on idempotency keys**
  *Why*: Don't store forever; a reasonable window (24h-7d) is usually sufficient.

---

## 4. At-Least-Once vs Exactly-Once vs Effectively-Once

- **At-least-once delivery**: Message is delivered one or more times
  *Why*: Most message systems guarantee this. Simplest to implement.

- **Exactly-once delivery**: Message is delivered exactly one time
  *Why*: Very difficult/impossible in distributed systems. Often marketing, not reality.

- **Effectively-once (idempotent processing)**: Message may be delivered multiple times, but effect happens once
  *Why*: Combine at-least-once delivery with idempotent consumers. Achievable and practical.

- **Design for effectively-once**:
  - Producer sends with unique message ID
  - Consumer tracks processed IDs
  - Duplicate deliveries are detected and skipped

---

## 5. Retry Patterns

- **Use exponential backoff with jitter**:
  ```csharp
  var delay = TimeSpan.FromSeconds(Math.Pow(2, attemptNumber))
              + TimeSpan.FromMilliseconds(Random.Shared.Next(0, 1000));
  ```
  *Why*: Prevents thundering herd when many clients retry simultaneously.

- **Set a maximum retry count**
  *Why*: Infinite retries against a failing service waste resources and may never succeed.

- **Use dead-letter queues for permanently failed messages**
  *Why*: Don't lose messages; move them aside for manual investigation.

- **Don't retry non-idempotent operations without idempotency keys**
  *Why*: Retrying a non-idempotent operation (e.g., create order) may create duplicates.

---

## 6. Preventing Retry Storms

- **Problem**: Service A calls Service B. B is slow. A retries. Retries add more load to B. B gets slower. More retries. Cascade failure.

- **Solutions**:
  - **Circuit breaker**: Stop calling B after N failures
  - **Backoff**: Increase delay between retries
  - **Jitter**: Randomize retry times to spread load
  - **Deadline propagation**: If original request deadline passed, don't retry
  - **Rate limiting**: Limit total outbound requests to B

- **Use Polly for .NET**:
  ```csharp
  Policy
      .Handle<HttpRequestException>()
      .WaitAndRetryAsync(3,
          attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))
                   + TimeSpan.FromMilliseconds(Random.Shared.Next(0, 1000)))
  ```

---

## 7. Circuit Breaker Pattern

- **Purpose**: Fail fast when a dependency is unhealthy
  *Why*: Don't wait for timeouts on every request to a known-failing service.

- **States**:
  - **Closed**: Normal operation, requests flow through
  - **Open**: Dependency is failing, requests fail immediately
  - **Half-Open**: Testing if dependency recovered

- **Implementation with Polly**:
  ```csharp
  Policy
      .Handle<HttpRequestException>()
      .CircuitBreakerAsync(
          exceptionsAllowedBeforeBreaking: 5,
          durationOfBreak: TimeSpan.FromSeconds(30))
  ```

- **Design fallbacks for open circuit**
  *Why*: Return cached data, default response, or graceful error instead of failing completely.

---

## 8. Timeouts

- **Set timeouts on all external calls**
  *Why*: Without timeouts, a hung connection consumes resources indefinitely.

- **Propagate deadlines through the call chain**
  *Why*: If the original request has 5s left, downstream calls should know and not take longer.

- **Use shorter timeouts for retries**
  *Why*: If first attempt gets 5s, retry attempts should get progressively less time.

- **Configure timeouts at multiple layers**:
  - HTTP client timeout
  - Database connection timeout
  - Query execution timeout
  - Overall request timeout

---

## 9. Bulkhead Pattern

- **Isolate failures to prevent cascade**
  *Why*: A slow database query shouldn't exhaust all threads and affect unrelated requests.

- **Implementation approaches**:
  - **Separate thread pools** per dependency
  - **Separate connection pools** per dependency
  - **Separate pods/services** for critical vs non-critical features

- **Example**: Order processing and reporting use separate database connections
  *Why*: Slow report queries don't exhaust connections needed for order processing.

---

## 10. Tail Latency and Hedged Requests

- **Understand tail latency (p99, p999)**
  *Why*: Average latency hides the worst cases. If p99 is 500ms but p99 is 5s, some users have terrible experience.

- **Causes of tail latency**:
  - GC pauses
  - Network congestion
  - Resource contention
  - Cold starts

- **Hedged requests**: Send request to multiple backends, use first response
  ```csharp
  var task1 = CallBackend1Async();
  var task2 = CallBackend2Async();
  var winner = await Task.WhenAny(task1, task2);
  return await winner;
  ```
  *Why*: Reduces tail latency at cost of extra load. Use sparingly.

- **Backup requests**: Send second request only if first is slow
  *Why*: Less wasteful than hedging; only duplicates when needed.

---

## 11. Partial Failures

- **Expect and handle partial failures**
  *Why*: In microservices, some services may be healthy while others are not.

- **Design for graceful degradation**:
  - If recommendation service is down, show products without recommendations
  - If payment service is slow, queue orders for later processing
  - If external API fails, use cached data

- **Use feature flags to disable degraded paths**
  *Why*: Quickly disable a failing feature without redeployment.

- **Implement health checks that reflect partial readiness**
  *Why*: A service may be able to serve some requests but not others.

---

## 12. Event-Driven Architecture

- **Use events for loose coupling between services**
  *Why*: Producer doesn't need to know consumers. New consumers can be added without changing producer.

- **Design events as immutable facts**
  *Why*: "Order Created" is a fact that happened. Events are not commands.

- **Version your event schemas**
  *Why*: Consumers may receive old and new event formats during transitions.

- **Use outbox pattern for reliable event publishing**:
  ```
  1. Write to database (order + outbox event) in transaction
  2. Background process reads outbox, publishes to queue
  3. Mark outbox record as published
  ```
  *Why*: Ensures event is published if and only if database write succeeds.

---

## 13. Ordering and Causality

- **Don't assume global ordering in distributed systems**
  *Why*: Events from different sources may arrive in different orders at different consumers.

- **Use sequence numbers for ordering within a partition**
  *Why*: Kafka, Service Bus sessions, and Event Hubs provide partition-level ordering.

- **Design for commutative operations where possible**
  *Why*: If operations can be applied in any order with same result, ordering doesn't matter.

- **Use vector clocks or logical timestamps for causal ordering**
  *Why*: Track happens-before relationships without global synchronization.

---

## 14. Split-Brain and Consensus

- **Split-brain**: Network partition causes two parts of system to operate independently
  *Why*: Each side may accept writes, causing conflicting state.

- **Prevention strategies**:
  - **Leader election with majority quorum**: Only one leader can exist
  - **Fencing tokens**: Old leader's requests are rejected by data stores
  - **External coordination**: Use etcd, ZooKeeper, or managed services

- **For most AKS applications**: Use managed databases with built-in consensus
  *Why*: Cosmos DB, Azure SQL, etc. handle split-brain internally. Don't build your own.

---

## 15. Database Hotspotting

- **Problem**: All requests hit the same database row/partition
  *Why*: Causes contention, lock waits, and throughput limits.

- **Causes**:
  - Sequential IDs (all inserts to latest partition)
  - Popular items (trending product gets all reads)
  - Global counters (all writes to single row)

- **Solutions**:
  - Use UUIDs or randomized prefixes for keys
  - Shard hot data across multiple rows/partitions
  - Use caching for read-heavy hot data
  - Batch and aggregate writes to counters

---

## 16. Thundering Herd

- **Problem**: Many clients simultaneously hit a resource
  *Why*: Cache expiry, scale-from-zero, or synchronized retries cause spike.

- **Scale-from-zero thundering herd**:
  - KEDA scales from 0 to 10 pods
  - All 10 pods start simultaneously
  - All 10 open database connections at once
  - Database overwhelmed

- **Solutions**:
  - **Staggered startup**: Random delay before connecting
  - **Connection pooling**: External pooler (PgBouncer) limits total connections
  - **Request coalescing**: Multiple waiters share single backend request
  - **Cache stampede prevention**: Lock while refreshing, others wait or get stale

---

## 17. Design Principles

- **Embrace failure as normal, not exceptional**
  *Why*: In distributed systems, something is always failing. Design for it.

- **Prefer availability over consistency for most user-facing operations**
  *Why*: Users prefer a response (even stale) over an error.

- **Make operations idempotent and retriable**
  *Why*: The foundation of reliable distributed systems.

- **Design for observability from the start**
  *Why*: You cannot debug distributed failures without traces and correlation.

- **Use managed services for coordination**
  *Why*: Don't build your own consensus, leader election, or distributed locks unless absolutely necessary.
