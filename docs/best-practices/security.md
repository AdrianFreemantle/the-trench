# AKS Security & Hardening Checklist

Layered, outside‑in view of controls to harden the cluster and workloads. Each item is phrased as "Do X" with a short "Why".

---

## 1. Azure Tenant, Subscription & Control Plane

- **Enforce Azure Policy on subscriptions and resource groups**  
  *Why*: Prevent insecure AKS and network configurations (e.g. public clusters, wrong CNI, public IPs on sensitive LBs, missing diagnostics).

- **Use Azure AD for AKS API authentication and disable local accounts**  
  *Why*: Centralized identity and access management, MFA/conditional access, easier revocation than kubectl client certs.

- **Define RBAC roles and scopes in Azure (least privilege)**  
  *Why*: Ensure operators, CI/CD, and automation only have the minimal permissions needed (e.g. separate infra-admin vs app-admin roles).

- **Enable diagnostic logging and send logs to Log Analytics / SIEM**  
  *Why*: Provide an audit trail for AKS, control plane, and network resources to investigate incidents and build alerts.

---

## 2. Network Edge: Firewall, VNet, NSGs

- **Place AKS in a private VNet, use Private Cluster if possible**  
  *Why*: Reduce attack surface by avoiding public API server and public node IPs; force access through controlled paths.

- **Use Azure Firewall or similar at the hub VNet edge**  
  *Why*: Central point to control egress/ingress to/from the internet and other networks, with logging and rule management.

- **Apply NSGs to AKS subnets and critical NICs**  
  *Why*: Enforce L3/L4 rules at subnet/NIC level, blocking unwanted inbound and outbound ports regardless of pod behavior.

- **Restrict outbound internet access from AKS node subnets**  
  *Why*: Prevent compromised workloads from freely exfiltrating data or calling arbitrary external services.

- **Use Private Endpoints and Private DNS for PaaS services (DB, KV, SB, etc.)**  
  *Why*: Keep traffic to Azure PaaS services on the private network, avoid public exposure of critical data services.

---

## 3. Cluster Admission & Configuration Governance

- **Use Gatekeeper (OPA) or Kyverno for admission control**  
  *Why*: Enforce organization policies on all Kubernetes objects at admission time (e.g. require labels, deny privileged pods, forbid public ingress).

- **Define and enforce Pod Security Standards (PSS) / Pod Security admission**  
  *Why*: Prevent pods from running with dangerous capabilities (privileged, host networking, hostPath, root user) unless explicitly allowed.

- **Require resource requests/limits for all pods**  
  *Why*: Avoid noisy-neighbor and resource exhaustion scenarios; allow scheduler and HPA to work correctly.

- **Enforce mandatory labels and ownership metadata**  
  *Why*: Make it easier to apply policies, cost allocation, and incident response (who owns this app, what environment is it in?).

- **Disallow creation of certain risky object types or settings**  
  *Why*: Block use of HostPath volumes, NodePort services, or LoadBalancers in restricted environments by policy.

---

## 4. Cluster Networking: Ingress & NetworkPolicy

- **Use an Ingress controller (e.g. NGINX) with TLS everywhere**  
  *Why*: Terminate HTTPS at the edge of the cluster, enforce encryption in transit from clients, and centralize routing.

- **Restrict which services may be exposed by Ingress**  
  *Why*: Ensure only explicitly approved services are reachable from outside, reduce accidental exposure of internal APIs.

- **Apply Kubernetes NetworkPolicy for all application namespaces**  
  *Why*: Treat NetworkPolicy as a per-namespace firewall to control pod-to-pod (east–west) and pod-to-external (egress) traffic.

- **Default-deny ingress for pods, allow only specific peers**  
  *Why*: Prevent lateral movement between workloads; only known callers (by namespace/label) can reach a service.

- **Constrain egress with NetworkPolicy plus Firewall/NSG**  
  *Why*: Ensure workloads can only talk to required endpoints (e.g. DNS, Azure AD, Key Vault, databases), reducing data exfiltration paths.

- **Separate ingress and app workloads into different namespaces/node pools**  
  *Why*: Isolate ingress controllers from application pods and apply stricter policies to ingress components.

---

## 5. Identity & Access: Pods, Apps, and Azure Resources

- **Use Kubernetes RBAC for service accounts (least privilege)**  
  *Why*: Control what in-cluster operations each workload can perform (e.g. listing secrets or configmaps), limiting blast radius.

- **Avoid in-cluster static secrets for Azure access; use UAMI + Workload Identity**  
  *Why*: Eliminate long-lived credentials; pods obtain short-lived tokens via their Kubernetes service account and user-assigned managed identity.

- **Use CSI Secret Store driver for secrets from Key Vault**  
  *Why*: Mount secrets at runtime from a trusted store with auditing and rotation, instead of embedding them in Kubernetes Secrets or files.

- **Restrict which identities can access which Azure resources**  
  *Why*: Ensure user-assigned managed identities only have the minimal RBAC on databases, Key Vault, Service Bus, etc.

- **Use TLS/mTLS for external service calls (databases, APIs)**  
  *Why*: Protect data in transit and enable stronger identity for services (e.g. Postgres over TLS, mTLS in service meshes).

- **Avoid username/password DB access; use AAD auth or MSI-based auth**  
  *Why*: Remove static DB credentials, improve rotation and revocation via identity-based access control.

---

## 6. Workload Security: Pods & Containers

- **Run containers as non-root users**  
  *Why*: Reduce the impact of container breakout vulnerabilities; root in the container can map to stronger privileges on the host.

- **Drop Linux capabilities not required by the app**  
  *Why*: Limit the kernel-level operations available to compromised containers, shrinking the attack surface.

- **Set `readOnlyRootFilesystem` where possible**  
  *Why*: Prevent attackers from modifying binaries/configs inside containers; force writes into controlled volumes.

- **Avoid sharing host namespaces and volumes unless strictly needed**  
  *Why*: Features like `hostNetwork`, `hostPID`, `hostIPC`, and `hostPath` break workload isolation and should be rare, audited exceptions.

- **Use liveness, readiness, and startup probes correctly**  
  *Why*: Ensure failed or unhealthy workloads are not serving traffic and can be restarted automatically when stuck.

- **Use PodDisruptionBudgets and rollout strategies**  
  *Why*: Maintain a minimum number of replicas available during maintenance and deployments, improving resilience.

---

## 7. Observability, Detection & Response

- **Centralize logs from Kubernetes, workloads, and ingress**  
  *Why*: Enable correlation across app logs, kube-system logs, and network logs for troubleshooting and forensics.

- **Enable and monitor Kubernetes audit logs**  
  *Why*: See who changed what (and when) in the cluster; detect suspicious configuration changes.

- **Set up alerts on key SLOs and security signals**  
  *Why*: Detect incidents early (e.g. spike in 5xx, CrashLoopBackOff, failed auth, unauthorized access attempts).

- **Use runtime security tools (e.g. Defender for Cloud, Falco, Tetragon)**  
  *Why*: Detect anomalous behavior at syscall or network layer (suspicious processes, outbound connections, crypto mining patterns).

- **Test incident response procedures regularly**  
  *Why*: Ensure on-call engineers know how to isolate a workload, revoke credentials, and roll back changes under time pressure.

---

## 8. Data Protection, Backup & Recovery

- **Encrypt data at rest for all storage (disks, databases, object storage)**  
  *Why*: Protect data if disks or backups are accessed outside normal control paths; meet compliance requirements.

- **Use customer-managed keys where required**  
  *Why*: Retain control over cryptographic material for highly sensitive or regulated workloads.

- **Implement regular backups for stateful services**  
  *Why*: Ensure you can recover from corruption, accidental deletion, or ransomware impacts.

- **Practice restore drills**  
  *Why*: Validate that backups are usable and that RPO/RTO objectives are realistic.

---

## 9. Supply Chain, CI/CD & Registry Security

- **Use gated CI/CD pipelines with code review and branch protection**  
  *Why*: Prevent unreviewed or untested changes from reaching main branches and production environments.

- **Perform static code analysis (SAST) and dependency scanning (SCA)**  
  *Why*: Catch insecure code patterns and vulnerable libraries early in the development lifecycle.

- **Scan container images for vulnerabilities before pushing**  
  *Why*: Ensure built images do not contain known CVEs or misconfigurations before they land in the registry.

- **Lock down container registry permissions (who can push/pull)**  
  *Why*: Prevent untrusted parties from publishing or downloading images; reduce risk of image tampering.

- **Use image signing and verification (e.g. Cosign)**  
  *Why*: Guarantee integrity and provenance of images running in the cluster; only allow signed images from trusted pipelines.

- **Separate duties: developers push code, GitOps/CD deploys manifests**  
  *Why*: Reduce the chance of manual, out-of-band changes; keep the cluster state driven from Git and controlled pipelines.

- **Pin base images and avoid `latest` tags**  
  *Why*: Make builds deterministic and auditable; avoid surprise upgrades when base images change.

---

## 10. Access Management & Secrets Hygiene

- **Minimize direct kubectl access; use break-glass accounts with approval**  
  *Why*: Reduce risk of accidental or malicious manual changes; keep most changes flowing through GitOps.

- **Limit access to Git repositories and branches**  
  *Why*: Protect the desired state of the cluster and application source; Git is a high-value target.

- **Avoid storing secrets in Git; use Key Vault + CSI or sealed secrets mechanisms**  
  *Why*: Prevent long-lived secrets from leaking via version control and backups.

- **Rotate secrets and credentials regularly**  
  *Why*: Limit the window of usefulness if secrets are compromised.

---

## 11. Design Principles

- **Defense in depth**  
  *Why*: Assume individual controls can fail; layer multiple independent protections (network, identity, config, runtime).

- **Least privilege**  
  *Why*: Grant only the permissions and network access required for a component to function.

- **Secure by default, explicit exceptions**  
  *Why*: Start from restrictive defaults (deny-all NetworkPolicies, restricted PodSecurity) and open only what is needed.

- **GitOps as the source of truth**  
  *Why*: Keep cluster state reproducible, auditable, and recoverable by having all config defined and versioned in Git.
