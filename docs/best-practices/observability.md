# AKS Observability Best Practices

Checklist-style guidance for logging, metrics, tracing, SLOs, and alerting in AKS and microservices.

---

## 1. Goals, SLOs & What to Observe

- **Define service-level objectives (SLOs) before instruments and dashboards**  
  *Why*: Observability should answer whether you are meeting reliability and performance goals (availability, latency, error rate), not just collect data.

- **Identify key SLIs for each service (e.g. latency, error rate, throughput)**  
  *Why*: Focusing on a small set of SLIs per service keeps dashboards and alerts meaningful.

- **Differentiate user-facing and internal SLOs**  
  *Why*: External SLOs reflect customer impact; internal SLOs guide engineering work and capacity planning.

- **Align observability design with incident response needs**  
  *Why*: Make sure data collected helps answer: What broke? Why? Since when? Who/what is impacted?

---

## 2. Logging Best Practices

- **Emit structured, machine-parsable logs (JSON)**  
  *Why*: Enables robust querying, filtering, and correlation across services and tools.

- **Include correlation IDs and request IDs in logs**  
  *Why*: Make it possible to follow a single request across multiple services and components.

- **Standardize log fields across services (service name, env, version, request_id, user_id)**  
  *Why*: Simplifies cross-service analysis and dashboarding.

- **Log at appropriate levels (DEBUG/INFO/WARN/ERROR) and avoid log spam**  
  *Why*: Reduce noise so important signals stand out; avoid excessive logging costs.

- **Avoid logging sensitive data (PII, secrets, tokens)**  
  *Why*: Reduce security and compliance risk and simplify log retention policies.

- **Use application logs, not only infrastructure logs**  
  *Why*: Kubernetes and node logs are not enough to understand business-level behavior and failures.

---

## 3. Metrics & Time-Series Data

- **Expose standard RED/USE metrics for HTTP services**  
  *Why*: Request rate, errors, and duration (RED) and utilization, saturation, errors (USE) provide a solid baseline for monitoring.

- **Use consistent metric names and labels across services**  
  *Why*: Easier to build reusable dashboards and alerts.

- **Collect both system metrics (nodes, pods) and application metrics**  
  *Why*: Need both infrastructure health and service-specific indicators to diagnose issues end-to-end.

- **Avoid high-cardinality metrics and unbounded label values**  
  *Why*: Prevent performance and cost issues in metrics backends.

- **Instrument critical code paths with explicit business-level metrics**  
  *Why*: Track domain-specific success/failure (e.g. orders placed, payments failed) alongside technical metrics.

---

## 4. Distributed Tracing

- **Adopt a standard tracing system (e.g. OpenTelemetry)**  
  *Why*: Provide end-to-end visibility across microservices and external dependencies using a common format.

- **Propagate trace context (trace ID, span ID) through all service calls**  
  *Why*: Allow reconstruction of complete request flows and identification of the slowest segments.

- **Instrument ingress, gateway, and critical intermediate services for tracing**  
  *Why*: Capture the full path from edge to backend services.

- **Sample traces thoughtfully (e.g. probabilistic, tail-based for errors/slow requests)**  
  *Why*: Keep tracing manageable in volume and cost while retaining high-value traces.

---

## 5. Centralization & Tooling

- **Centralize logs from AKS and workloads into a single platform**  
  *Why*: Enable global search and correlation (e.g. Log Analytics, Elastic, Loki).

- **Centralize metrics into a time-series database with dashboards (e.g. Prometheus + Grafana)**  
  *Why*: Provide unified views across services and infrastructure.

- **Integrate tracing into the same observability stack where possible**  
  *Why*: Make it easy to pivot from metrics to traces to logs for the same incident.

- **Automate configuration of scrapers/collectors (e.g. via Helm, Operators)**  
  *Why*: Ensure new services are consistently observed without manual steps.

---

## 6. Kubernetes-Specific Observability

- **Collect Kubernetes control plane and kube-system logs**  
  *Why*: Diagnose cluster-level issues (scheduling, Kubelet, DNS, CNI) impacting workloads.

- **Monitor core Kubernetes metrics (pods, nodes, API server, etcd, scheduler)**  
  *Why*: Detect resource pressure, API errors, and control-plane performance issues early.

- **Track workload health via probes and status conditions**  
  *Why*: Use `Ready`, `Available`, `CrashLoopBackOff`, and probe failures as key signals for alerting and dashboards.

- **Instrument ingress controllers and service meshes**  
  *Why*: Obtain request-level metrics and logs for all inbound and cross-service traffic.

- **Visualize cluster topology (namespaces, services, dependencies)**  
  *Why*: Understand how services interact and identify blast radius during incidents.

---

## 7. Dashboards & Visualization

- **Create service-centric dashboards aligned with SLOs**  
  *Why*: Show the health of a service at a glance: latency, error rate, throughput, saturation.

- **Provide infrastructure dashboards (nodes, pods, network, storage)**  
  *Why*: Quickly determine whether an incident is infra-related vs. application-specific.

- **Build high-level business dashboards (e.g. orders, revenue, sign-ups)**  
  *Why*: Correlate technical incidents with business impact.

- **Standardize dashboard layout and naming**  
  *Why*: Make it easy for engineers to navigate between services and environments.

- **Avoid dashboard sprawl; review and prune periodically**  
  *Why*: Keep dashboards relevant, discoverable, and maintained.

---

## 8. Alerting Strategy

- **Alert on symptoms that affect users (SLO violations)**  
  *Why*: Focus on what impacts customers (error rate, latency, availability), not only internal metrics.

- **Use multi-level alerts (warning vs critical)**  
  *Why*: Differentiate between early signals and urgent, user-impacting issues.

- **Route alerts to on-call with clear ownership**  
  *Why*: Ensure someone is responsible for responding to each alert.

- **Design alerts with runbook links and context**  
  *Why*: Help responders act quickly, knowing where to look and what to try first.

- **Continuously tune alerts to reduce noise and avoid alert fatigue**  
  *Why*: Too many false positives cause real alerts to be ignored.

- **Test alerting paths regularly (e.g. synthetic events)**  
  *Why*: Ensure alerts actually reach people and automation when needed.

---

## 9. Logging, Metrics, and Tracing in CI/CD

- **Validate instrumentation in automated tests where practical**  
  *Why*: Ensure critical endpoints and flows emit expected metrics and logs.

- **Include observability configuration in version control (GitOps)**  
  *Why*: Keep dashboards, alert rules, and collectors declarative, reviewable, and reproducible.

- **Use pre-production environments to validate observability**  
  *Why*: Confirm that new services are properly instrumented before they reach production.

- **Fail fast on missing critical observability plumbing for key services**  
  *Why*: Treat lack of instrumentation for critical paths as a deployment readiness issue.

---

## 10. Incident Response & Post-Incident Learning

- **Train teams to use observability tools during drills and game days**  
  *Why*: Build muscle memory for quickly finding and interpreting relevant signals.

- **Use observability data heavily in post-incident reviews**  
  *Why*: Base improvements on concrete evidence about what happened and how the system behaved.

- **Track incident detection and diagnosis times**  
  *Why*: Measure how well observability supports fast detection and root-cause analysis.

- **Feed lessons learned back into instrumentation and alerts**  
  *Why*: Continuously improve observability so the same type of incident is detected and understood faster next time.

---

## 11. Design Principles for Observability

- **Treat observability as a first-class feature, not an afterthought**  
  *Why*: Retrofitting instrumentation is harder and often incomplete; design with observability in mind from the start.

- **Prefer standard, shared libraries and patterns for instrumentation**  
  *Why*: Reduce per-service variance and encourage consistent practices.

- **Make it easy for developers to add and update instrumentation**  
  *Why*: Lower the barrier to improving observability as services evolve.

- **Correlate logs, metrics, and traces wherever possible**  
  *Why*: Speed up root cause analysis by enabling easy navigation across different signal types.

- **Review observability regularly as part of architecture and design reviews**  
  *Why*: Ensure new services and changes remain observable as the system grows in complexity.
