# .NET on AKS Best Practices

Checklist-style guidance for running .NET applications on AKS, covering container tuning, connection management, and common pitfalls.

---

## 1. Container Resource Configuration

- **Set memory limits based on your workload profile**
  *Why*: .NET GC behavior changes based on available memory. Too low causes frequent GC; too high wastes cluster resources.

- **Set CPU requests and limits appropriately**
  *Why*: CPU throttling causes latency spikes. Requests affect scheduling; limits affect throttling.

- **Use `DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_HTTP2UNENCRYPTED` for gRPC**
  *Why*: Enables HTTP/2 without TLS for internal cluster communication.

- **Consider setting `DOTNET_gcServer=1` for high-throughput services**
  *Why*: Server GC is optimized for throughput on multi-core machines. Default in containers may use Workstation GC.

---

## 2. Kestrel Tuning for Containers

- **Configure Kestrel limits explicitly**
  ```csharp
  builder.WebHost.ConfigureKestrel(options =>
  {
      options.Limits.MaxConcurrentConnections = 1000;
      options.Limits.MaxConcurrentUpgradedConnections = 1000;
      options.Limits.MaxRequestBodySize = 10 * 1024 * 1024; // 10 MB
      options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
      options.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);
  });
  ```
  *Why*: Default limits may be too conservative or too permissive for your workload.

- **Use HTTP/2 for internal services**
  *Why*: Multiplexing reduces connection overhead for high-throughput internal APIs.

- **Configure listen addresses for container networking**
  ```csharp
  options.Listen(IPAddress.Any, 8080);
  ```
  *Why*: Don't bind to localhost in containers; bind to 0.0.0.0 or specific IPs.

---

## 3. HttpClient and Connection Management

- **Always use IHttpClientFactory**
  ```csharp
  services.AddHttpClient("catalog-api", client =>
  {
      client.BaseAddress = new Uri("http://catalog-api.apps.svc.cluster.local");
      client.Timeout = TimeSpan.FromSeconds(30);
  });
  ```
  *Why*: Factory manages HttpMessageHandler lifetime, preventing socket exhaustion and DNS issues.

- **Never create HttpClient instances directly in hot paths**
  *Why*: Each `new HttpClient()` creates new connections. In a loop, this exhausts sockets rapidly.

- **Configure DNS refresh for HttpClientFactory**
  ```csharp
  services.AddHttpClient("external-api")
      .SetHandlerLifetime(TimeSpan.FromMinutes(5));
  ```
  *Why*: Default handler lifetime is 2 minutes. For Kubernetes Services, DNS can change during pod scaling.

- **Use Polly for retry and circuit breaker patterns**
  ```csharp
  services.AddHttpClient("catalog-api")
      .AddTransientHttpErrorPolicy(p =>
          p.WaitAndRetryAsync(3, _ => TimeSpan.FromMilliseconds(300)))
      .AddTransientHttpErrorPolicy(p =>
          p.CircuitBreakerAsync(5, TimeSpan.FromSeconds(30)));
  ```
  *Why*: Transient failures are common in distributed systems. Retries improve reliability.

---

## 4. Preventing Socket Exhaustion

- **Symptoms**: `SocketException: Address already in use`, connection timeouts, port exhaustion

- **Root causes**:
  - Creating HttpClient instances directly
  - Not disposing connections properly
  - High volume of short-lived connections

- **Solutions**:
  - Use IHttpClientFactory (handles connection pooling)
  - Configure connection limits per handler
  - Increase socket reuse timeout at OS level (container image)

- **Monitor with**:
  ```csharp
  // Add connection metrics
  services.AddHttpClient("api")
      .AddHttpMessageHandler<MetricsHandler>();
  ```

---

## 5. Connection Pooling for Databases

- **For Npgsql (PostgreSQL)**:
  ```csharp
  services.AddNpgsqlDataSource(
      "Host=postgres;Database=mydb;Username=app;Password=xxx;Pooling=true;MinPoolSize=5;MaxPoolSize=50");
  ```
  *Why*: Connection pooling reuses connections; min pool size prevents cold-start latency.

- **For SQL Server**:
  ```csharp
  "Server=sql;Database=mydb;User Id=app;Password=xxx;TrustServerCertificate=True;Min Pool Size=5;Max Pool Size=50;"
  ```
  *Why*: Similar pooling configuration for SQL Server connections.

- **For Redis (StackExchange.Redis)**:
  ```csharp
  services.AddSingleton<IConnectionMultiplexer>(sp =>
      ConnectionMultiplexer.Connect("redis:6379,abortConnect=false"));
  ```
  *Why*: ConnectionMultiplexer is thread-safe and should be singleton. One connection per app instance.

- **Design principle**: Calculate max connections = pods × maxPoolSize. Ensure database can handle this.

---

## 6. Preventing Connection Storms During Scale-Out

- **Problem**: When KEDA scales from 1 to 50 pods, all 50 open database connections simultaneously
  *Why*: Database gets 50 × maxPoolSize connection attempts, may reject or timeout.

- **Solutions**:
  - **Gradual connection opening**: Don't warm pool on startup
  - **Connection queuing**: Let pool handle back-off naturally
  - **External pooler**: PgBouncer in front of PostgreSQL
  - **Scale incrementally**: Use KEDA's `cooldownPeriod` and `pollingInterval`

- **Use health checks that don't depend on full connectivity**
  *Why*: Don't fail liveness probe just because DB pool is exhausted.

---

## 7. Thread Pool and Async/Await

- **Understand thread pool behavior in containers**
  *Why*: .NET adjusts thread pool based on available cores. Containers report cgroup limits.

- **Avoid blocking on async code**
  ```csharp
  // Bad - can cause deadlocks and thread pool starvation
  var result = GetDataAsync().Result;

  // Good - async all the way
  var result = await GetDataAsync();
  ```
  *Why*: Blocking consumes thread pool threads, which are limited in containers.

- **Monitor thread pool exhaustion**
  ```csharp
  ThreadPool.GetAvailableThreads(out int workerThreads, out int completionPortThreads);
  ```
  *Why*: Thread pool exhaustion causes request queuing and timeouts.

- **Consider setting minimum threads**
  ```csharp
  ThreadPool.SetMinThreads(100, 100);
  ```
  *Why*: Prevents slow ramp-up under sudden load. Trade-off: memory usage.

---

## 8. Detecting Thread Pool Starvation

- **Symptoms**: High latency, requests timing out, low CPU usage despite high load

- **Diagnosis**:
  ```csharp
  // Add to health check or metrics
  ThreadPool.GetMinThreads(out int minWorker, out int minIO);
  ThreadPool.GetMaxThreads(out int maxWorker, out int maxIO);
  ThreadPool.GetAvailableThreads(out int availWorker, out int availIO);
  ```

- **If available threads near zero**: Thread pool is exhausted

- **Common causes**:
  - Blocking async calls (`.Result`, `.Wait()`)
  - Synchronous I/O on async path
  - Too many concurrent requests for available threads

- **Solutions**:
  - Fix blocking code
  - Increase min threads
  - Add rate limiting to prevent overload

---

## 9. Memory and GC Tuning

- **Understand container memory limits**
  *Why*: .NET respects cgroup limits. A 512MB container limit means .NET sees 512MB total.

- **Configure GC mode based on workload**:
  - **Server GC** (`DOTNET_gcServer=1`): High throughput, more memory, parallel collection
  - **Workstation GC** (default in containers): Lower memory, single-threaded GC

- **Monitor GC metrics**:
  ```csharp
  // Gen 0, 1, 2 collections
  GC.CollectionCount(0);
  GC.CollectionCount(1);
  GC.CollectionCount(2);
  GC.GetTotalMemory(forceFullCollection: false);
  ```

- **Symptoms of memory pressure**:
  - Frequent Gen 2 collections
  - High GC pause times
  - OutOfMemoryException

---

## 10. Diagnosing Memory Issues in Containers

- **Differentiate GC pressure from memory leaks**:
  - **GC pressure**: Memory grows, GC runs, memory drops. Repeat.
  - **Memory leak**: Memory grows continuously, never drops.

- **Capture memory dumps in Kubernetes**:
  ```bash
  kubectl exec <pod> -- dotnet-dump collect -p 1 -o /tmp/dump.dmp
  kubectl cp <pod>:/tmp/dump.dmp ./dump.dmp
  ```
  *Why*: Analyze with `dotnet-dump analyze` or Visual Studio.

- **Use metrics for ongoing monitoring**:
  - Gen 0/1/2 collection counts
  - GC heap size
  - LOH (Large Object Heap) size

- **Common memory issues in .NET**:
  - Not disposing IDisposable objects
  - Event handler leaks
  - Static collections growing unbounded
  - Large object allocations in hot paths

---

## 11. Graceful Shutdown

- **Handle SIGTERM in your application**:
  ```csharp
  var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
  lifetime.ApplicationStopping.Register(() =>
  {
      // Stop accepting new work
      // Wait for in-flight requests
      // Close connections
  });
  ```

- **Configure shutdown timeout**:
  ```csharp
  builder.Host.ConfigureHostOptions(options =>
  {
      options.ShutdownTimeout = TimeSpan.FromSeconds(30);
  });
  ```
  *Why*: Match this with Kubernetes `terminationGracePeriodSeconds`.

- **Use cancellation tokens throughout**:
  ```csharp
  public async Task ProcessAsync(CancellationToken stoppingToken)
  {
      while (!stoppingToken.IsCancellationRequested)
      {
          await DoWorkAsync(stoppingToken);
      }
  }
  ```
  *Why*: Allows clean cancellation of background work during shutdown.

---

## 12. Health Checks

- **Implement proper health endpoints**:
  ```csharp
  services.AddHealthChecks()
      .AddCheck("self", () => HealthCheckResult.Healthy())
      .AddNpgSql(connectionString, name: "postgres")
      .AddRedis(redisConnectionString, name: "redis");
  ```

- **Separate liveness from readiness**:
  - **Liveness**: Is the app alive? Restart if not.
  - **Readiness**: Can the app serve traffic? Remove from service if not.

- **Don't include dependency health in liveness**:
  *Why*: If database is down, restarting your app won't help. Use readiness instead.

- **Configure in Kubernetes**:
  ```yaml
  livenessProbe:
    httpGet:
      path: /healthz/live
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /healthz/ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
  ```

---

## 13. Observability for .NET

- **Use OpenTelemetry for traces, metrics, and logs**:
  ```csharp
  builder.Services.AddOpenTelemetry()
      .WithTracing(tracing => tracing
          .AddAspNetCoreInstrumentation()
          .AddHttpClientInstrumentation()
          .AddNpgsql()
          .AddOtlpExporter())
      .WithMetrics(metrics => metrics
          .AddAspNetCoreInstrumentation()
          .AddHttpClientInstrumentation()
          .AddOtlpExporter());
  ```

- **Add correlation IDs to all logs**:
  *Why*: Trace requests across services using Activity.Current?.TraceId.

- **Export to cluster observability stack**:
  *Why*: Send telemetry to Prometheus/Grafana/Jaeger running in your cluster.

---

## 14. Design Principles for .NET on AKS

- **Async all the way**
  *Why*: Maximize throughput with limited threads. Never block on async.

- **Use dependency injection for all external resources**
  *Why*: Proper lifetime management prevents leaks and enables testing.

- **Configure explicitly, don't rely on defaults**
  *Why*: Container defaults may differ from development machine. Be explicit.

- **Monitor the .NET runtime, not just business metrics**
  *Why*: GC, thread pool, and connection pool health predict problems before they impact users.

- **Test with container limits in development**
  *Why*: `docker run -m 512m` reveals memory issues before production.
