# Networking & Ingress Best Practices

Layered view of how traffic flows from the public internet down to a container in AKS, and how each layer is secured. Useful for explaining an "ingress stack" end-to-end.

High-level path:

> edge → regional entry → hub/spoke VNet → NSG/Firewall → ingress controller → pod/network policy → container/app

---

## 1. Global Edge & Public Entry (CDN / Front Door / Cloudflare)

- **Use a global edge (e.g. Azure Front Door, Cloudflare, CDN) in front of regional services**  
  *Why*: Provide low-latency access globally, absorb DDoS closer to users, and centralize public entrypoints.

- **Enable DDoS protection at the edge**  
  *Why*: Protect upstream services from volumetric attacks before they reach your VNets or clusters.

- **Use WAF (Web Application Firewall) at the edge**  
  *Why*: Block common web attacks (SQLi, XSS, etc.) and enforce basic request sanity BEFORE traffic enters your core network.

- **Terminate TLS at the edge with strong ciphers and managed certificates**  
  *Why*: Offload TLS from downstream components where appropriate, simplify cert management, and ensure secure protocols.

- **Route only to approved regional backends**  
  *Why*: Prevent misconfiguration where the edge could send traffic to unintended endpoints.

---

## 2. Regional Ingress into VNets (APIM / App Gateway / Regional Front Door)

- **Use an API gateway (e.g. APIM) or Application Gateway per region**  
  *Why*: Provide a controlled API surface, rate limiting, auth, and routing between the edge and internal services.

- **Perform TLS termination at the gateway where suitable**  
  *Why*: Offload expensive TLS from NGINX/ingress where CPU is tight, and centralize cert rotation.

- **Enforce authentication and authorization at the gateway for external clients**  
  *Why*: Stop unauthenticated or unauthorized traffic early, reduce burden on downstream services.

- **Expose only necessary paths and backends through the gateway**  
  *Why*: Reduce attack surface; keep internal-only services unreachable from the public edge.

- **Use WAF on regional gateways when not using a global WAF**  
  *Why*: Ensure HTTP-layer protections exist at least at one boundary before VNet traffic.

---

## 3. Hub/Spoke VNets, Routing & Private Endpoints

- **Adopt a hub/spoke VNet topology**  
  *Why*: Centralize shared services (firewall, DNS, VPN) in the hub while keeping AKS and app infra in isolated spokes.

- **Route all egress from AKS spokes via a hub firewall or egress appliance**  
  *Why*: Gain a single control point for outbound traffic inspection, filtering, and logging.

- **Use NSGs on subnets (and NICs when needed)**  
  *Why*: Enforce L3/L4 allow/deny rules regardless of pod behavior; NSGs are your last line inside the VNet.

- **Use Private Endpoints and Private DNS for PaaS (DB, Key Vault, Service Bus, Storage)**  
  *Why*: Ensure traffic to critical services flows over private IPs, not public internet, and can be governed by NSGs and firewall rules.

- **Avoid exposing PaaS services publicly when using Private Endpoints**  
  *Why*: Keep the only reachable interface on the private network; reduce the need for broad firewall exceptions.

---

## 4. AKS Ingress Layer (Ingress Controller & Services)

- **Use an ingress controller (e.g. NGINX Ingress) for HTTP(S) routing inside the cluster**  
  *Why*: Centralize path/host routing from VNet entry to internal services; avoid exposing NodePorts directly.

- **Decide where TLS terminates (Gateway vs Ingress vs App)**  
  *Why*: TLS termination is CPU-intensive; terminating at the gateway offloads work from NGINX and app pods, but sometimes end-to-end TLS to the pod is required.

- **Expose only ingress controllers to the VNet edge; keep app services ClusterIP**  
  *Why*: Avoid direct access to pods/services from outside the cluster; enforce routing through ingress policies.

- **Restrict which Services can be targeted by Ingress**  
  *Why*: Prevent accidental exposure of internal-only services via misconfigured Ingress objects.

- **Instrument and protect ingress (WAF annotations, rate limiting, auth, mTLS where needed)**  
  *Why*: Treat ingress as part of your security perimeter, not just a load balancer.

---

## 5. In-Cluster Networking: Services, DNS & NetworkPolicy

- **Use ClusterIP Services and internal DNS (`*.svc.cluster.local`) for service-to-service calls**  
  *Why*: Provide stable names and load balancing for pods without exposing them externally.

- **Apply Kubernetes NetworkPolicy for pod-to-pod and pod-to-external traffic**  
  *Why*: Implement L3/L4 firewalling inside the cluster, limiting which namespaces/pods/IPs and ports each workload can reach.

- **Default-deny ingress for application namespaces**  
  *Why*: Require explicit allow rules for any pod to be reached, reducing lateral movement.

- **Constrain egress from sensitive workloads using NetworkPolicy + firewall/NSG**  
  *Why*: Ensure workloads only talk to necessary services (DNS, Azure AD, private endpoints) and not arbitrary internet hosts.

- **Consider a service mesh (Istio, Linkerd, Cilium, etc.) for advanced traffic control**  
  *Why*: Add mTLS between services, fine-grained L7 authz, and richer traffic policies when justified by complexity.

---

## 6. Pod & Container Layer

- **Use service accounts and RBAC per workload**  
  *Why*: Control what each pod can do inside the cluster API (config access, secrets, etc.).

- **Run containers as non-root with minimal capabilities**  
  *Why*: Reduce impact of a compromised container and limit what it can do on the host.

- **Implement app-layer auth, rate limiting, and input validation**  
  *Why*: Protect from abuse and injection at the application boundary; NetworkPolicy works at L3/L4, not HTTP path/method.

- **Honor termination signals and support graceful shutdown**  
  *Why*: Allow pods to drain and finish in-flight requests when deployments or failures occur.

- **Use connection pooling and backpressure within containers**  
  *Why*: Avoid exhausting upstream/downstream connections, protect shared resources, and prevent cascading failures.

---

## 7. Putting It Together – Explaining the Stack

When asked to "explain your ingress stack", you can walk it layer by layer:

- **Edge / Global**: Cloudflare or Azure Front Door in front of everything. Does DDoS protection, WAF, TLS termination for public clients, and routes to regional backends.

- **Regional entry**: API Management or Application Gateway inside the region. Handles regional WAF, auth, rate limiting, and, where appropriate, TLS termination before traffic enters the spoke VNet.

- **Hub/Spoke & Firewall**: Traffic from the gateway enters the hub VNet, passes through Azure Firewall, and is routed to the AKS spoke VNet. The firewall uses service tags/FQDN rules to allow only specific outbound services (e.g. Azure AD), while PaaS access is via Private Endpoints.

- **VNet & NSGs**: The AKS node subnet is protected with NSGs and UDRs. All 0.0.0.0/0 egress from nodes goes to the firewall; PaaS traffic stays within the spoke via Private Endpoints.

- **Ingress controller (AKS)**: An internal NGINX ingress controller receives traffic from the VNet, applies host/path routing, and forwards to ClusterIP Services. Only the ingress controller is reachable from outside the cluster.

- **Pods & NetworkPolicy**: `NetworkPolicy` enforces which namespaces/pods can talk to which Services and external IPs/ports (e.g. demo-api → catalog-api, catalog-api → Postgres PE only).

- **Containers / App**: Inside the pod, the app implements authentication/authorization, rate limiting, input validation, timeouts, retries, and logging. Containers run as non-root with least privilege.

This layered story ties directly into the security, reliability, and observability docs:

- Security: which layers enforce auth, WAF, firewalling, and isolation.
- Reliability: how load is balanced and failures are contained between layers.
- Observability: where you measure and log (edge, gateway, ingress, app).

You can tailor which components you mention (Cloudflare vs Front Door, APIM vs App GW) based on the environment you’re describing, but the **pattern** remains the same: multiple, clearly defined layers, each with its own responsibilities and controls.
