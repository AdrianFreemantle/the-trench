# Troubleshooting & Operations Best Practices

Checklist-style guidance for debugging common AKS issues, cluster operations, and incident response.

---

## 1. Pod Stuck in Pending

- **Check for insufficient resources**
  ```bash
  kubectl describe pod <pod-name> -n <namespace>
  # Look for: "Insufficient cpu", "Insufficient memory"
  ```
  *Why*: No node has enough allocatable resources for the pod's requests.

- **Check for node selector/affinity mismatches**
  *Why*: Pod requires specific labels (e.g., `node-type: gpu`) that no nodes have.

- **Check for taint/toleration issues**
  *Why*: Nodes are tainted but pod lacks matching tolerations.

- **Check for PersistentVolumeClaim pending**
  *Why*: PVC not bound to a PV. Check storage class provisioner status.

- **Check if Cluster Autoscaler is at max capacity**
  ```bash
  kubectl get nodes
  kubectl describe configmap cluster-autoscaler-status -n kube-system
  ```
  *Why*: If node pools are at max, new nodes cannot be provisioned.

- **Resolution**: Increase node pool max count, adjust resource requests, add node pools, or remove conflicting affinity rules.

---

## 2. Pod Running but Not Responding

- **Check readiness probe status**
  ```bash
  kubectl describe pod <pod-name> | grep -A 5 "Readiness"
  ```
  *Why*: Pod may be running but failing readiness checks, so it's not in Service endpoints.

- **Check if pod is in Endpoints**
  ```bash
  kubectl get endpoints <service-name>
  ```
  *Why*: If pod IP not listed, traffic isn't routed to it.

- **Check application logs for errors**
  ```bash
  kubectl logs <pod-name> --tail=100
  ```
  *Why*: App may be crashing, deadlocked, or in an error state.

- **Check resource throttling (CPU limits)**
  *Why*: Pod hitting CPU limit is throttled, causing slow responses.

- **Exec into pod to test connectivity**
  ```bash
  kubectl exec -it <pod-name> -- /bin/sh
  curl localhost:8080/health
  ```
  *Why*: Determine if app is responding locally but failing at network level.

- **Check NetworkPolicy blocking traffic**
  *Why*: Ingress NetworkPolicy may prevent traffic from reaching the pod.

---

## 3. Image Pull Failures

- **Check pod events for pull errors**
  ```bash
  kubectl describe pod <pod-name> | grep -A 10 "Events"
  # Look for: ErrImagePull, ImagePullBackOff
  ```

- **For private registries, verify imagePullSecrets**
  ```bash
  kubectl get pod <pod-name> -o jsonpath='{.spec.imagePullSecrets}'
  ```
  *Why*: Secret must exist in the same namespace and contain valid credentials.

- **For ACR with managed identity, check kubelet identity**
  *Why*: AKS kubelet identity needs AcrPull role on the ACR.

- **In private clusters, check network path to registry**
  *Why*: Without proper egress rules or Private Endpoint, nodes cannot reach ACR.

- **Verify image tag exists**
  ```bash
  az acr repository show-tags --name <acr-name> --repository <repo>
  ```
  *Why*: Typos in image tag or deleted images cause pull failures.

---

## 4. Ingress Timeouts

- **Check ingress controller pod health**
  ```bash
  kubectl get pods -n ingress-nginx
  kubectl logs -n ingress-nginx <nginx-pod> --tail=100
  ```
  *Why*: Ingress controller itself may be overloaded or crashing.

- **Verify Service endpoints**
  ```bash
  kubectl get endpoints <backend-service>
  ```
  *Why*: If no endpoints, ingress has nowhere to route traffic.

- **Check ingress resource configuration**
  ```bash
  kubectl describe ingress <ingress-name>
  ```
  *Why*: Misconfigured paths, hosts, or annotations cause routing failures.

- **Review timeout settings**
  *Why*: Default NGINX timeouts (60s) may be too short for slow backends. Adjust with annotations.
  ```yaml
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "120"
  ```

- **Check backend application health**
  *Why*: If backends are slow or failing, ingress times out waiting for response.

---

## 5. DNS Failures Inside AKS

- **Test DNS resolution from a pod**
  ```bash
  kubectl exec -it <pod-name> -- nslookup kubernetes.default
  kubectl exec -it <pod-name> -- nslookup <external-host>
  ```

- **Check CoreDNS pods are healthy**
  ```bash
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  kubectl logs -n kube-system <coredns-pod>
  ```
  *Why*: CoreDNS crashes or resource exhaustion cause cluster-wide DNS failures.

- **Check CoreDNS scaling**
  *Why*: Large clusters may overwhelm default CoreDNS replicas. Consider autoscaling.

- **Verify NetworkPolicy allows DNS traffic**
  *Why*: Egress policy must allow UDP/TCP 53 to kube-system or the CoreDNS Service IP.

- **For external DNS, check egress path**
  *Why*: If cluster uses custom DNS servers or Azure Firewall, ensure DNS traffic is allowed.

- **Check /etc/resolv.conf in the pod**
  ```bash
  kubectl exec <pod-name> -- cat /etc/resolv.conf
  ```
  *Why*: Verify nameserver points to CoreDNS Service IP (usually 10.0.0.10).

---

## 6. What Happens When a Node Dies

- **Kubernetes detects node not ready after node-monitor-grace-period (default 40s)**
  *Why*: Kubelet stops heartbeating, node status becomes NotReady.

- **Pod eviction starts after pod-eviction-timeout (default 5m)**
  *Why*: Controller manager waits before assuming pods need rescheduling.

- **Pods are rescheduled to healthy nodes**
  *Why*: Deployments/ReplicaSets create replacement pods on other nodes.

- **Stateful workloads with Azure Disks take longer**
  *Why*: Disk must be detached from failed node (6+ minutes) before attaching to new node.

- **To speed recovery**: Use shorter tolerations on pods for `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable`.

---

## 7. Node Drain and Eviction

- **Node drain is a voluntary disruption**
  ```bash
  kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
  ```
  *Why*: Gracefully evicts pods, respecting PDBs and terminationGracePeriod.

- **PodDisruptionBudgets are honored during drain**
  *Why*: Drain blocks if evicting a pod would violate PDB. Ensure PDBs aren't too restrictive.

- **Pods receive SIGTERM, then SIGKILL after grace period**
  *Why*: Applications should handle SIGTERM to finish work and shutdown cleanly.

- **Use preStop hooks to delay shutdown**
  *Why*: Allow time for load balancer to stop sending traffic before app stops.

- **DaemonSets are not evicted by default**
  *Why*: Use `--ignore-daemonsets` because DaemonSets must run on every node.

---

## 8. Cluster Upgrades with Minimal Downtime

- **Understand the upgrade sequence**:
  1. Control plane upgraded first (managed by Azure)
  2. Node pools upgraded (node-by-node with cordon/drain)

- **Use Blue/Green node pool upgrades for critical workloads**
  *Why*: Create new node pool with new version, migrate workloads, delete old pool.

- **Configure max surge for node pool upgrades**
  ```bash
  az aks nodepool update --max-surge 33%
  ```
  *Why*: Adds extra nodes during upgrade, reducing pressure on remaining capacity.

- **Ensure PDBs allow rolling upgrades**
  *Why*: Overly restrictive PDBs block node drains during upgrades.

- **Test upgrades in staging first**
  *Why*: API deprecations or behavior changes may break workloads.

- **Schedule upgrades during low-traffic windows**
  *Why*: Even with zero-downtime design, upgrades add risk. Reduce user impact.

---

## 9. Certificate Rotation

- **AKS auto-rotates cluster certificates (kubelet, API server)**
  *Why*: Azure manages certificate lifecycle for managed clusters.

- **Monitor certificate expiry**
  ```bash
  az aks show -g <rg> -n <cluster> --query "azurePortalFqdn"
  ```
  *Why*: Expired certificates cause API server authentication failures.

- **Trigger manual rotation if needed**
  ```bash
  az aks rotate-certs -g <rg> -n <cluster>
  ```
  *Why*: If you suspect certificate compromise or need immediate rotation.

- **Warning: Certificate rotation causes brief API server downtime**
  *Why*: Plan for a maintenance window; control plane restarts.

---

## 10. Debugging Workflow

- **Step 1: Identify the symptom**
  - Users report errors → check application logs
  - Pods crashing → check pod events and logs
  - High latency → check resource utilization and traces

- **Step 2: Narrow the scope**
  - Single pod or all pods?
  - Single service or multiple?
  - Started with a deployment or infrastructure change?

- **Step 3: Gather evidence**
  ```bash
  kubectl get events --sort-by='.lastTimestamp' | tail -20
  kubectl top pods -n <namespace>
  kubectl describe pod/svc/ingress <name>
  kubectl logs <pod> --previous  # if container restarted
  ```

- **Step 4: Form hypothesis and test**
  - If resource exhaustion → check limits and requests
  - If networking → test with curl/nslookup from within cluster
  - If configuration → compare working vs broken environments

- **Step 5: Fix and verify**
  - Apply fix, monitor, confirm resolution

---

## 11. Investigating Container Crashes

- **Check exit code**
  ```bash
  kubectl describe pod <pod> | grep -A 5 "Last State"
  ```
  - Exit 0: Clean shutdown
  - Exit 1: Application error
  - Exit 137: OOMKilled (128 + 9)
  - Exit 143: SIGTERM (128 + 15)

- **For OOMKilled**
  *Why*: Container exceeded memory limit. Increase limits or fix memory leak.

- **Check previous container logs**
  ```bash
  kubectl logs <pod> --previous
  ```
  *Why*: If container restarted, previous logs show what happened before crash.

- **Check liveness probe configuration**
  *Why*: Overly aggressive liveness probes kill healthy but slow containers.

---

## 12. Performance Degradation After Rollout

- **Immediate actions**:
  1. Check if rollout is still in progress
  2. Compare metrics before/after (latency, error rate, CPU)
  3. Check what changed (image, config, replicas)

- **If new version is the cause, rollback**
  ```bash
  kubectl rollout undo deployment/<name>
  ```
  *Why*: Restore service first, investigate later.

- **If configuration change, revert config**
  *Why*: ConfigMap or Secret changes may have broken the application.

- **Post-incident**: Conduct blameless post-mortem, identify what testing missed.

---

## 13. Operational Best Practices

- **Maintain runbooks for common scenarios**
  *Why*: Documented procedures reduce MTTR and human error during incidents.

- **Use GitOps for all cluster changes**
  *Why*: Every change is auditable, reviewable, and reversible via Git.

- **Set up alerts for key failure signals**
  - Pod restarts, CrashLoopBackOff
  - Node NotReady
  - PVC pending
  - Certificate expiry
  - Cluster autoscaler failures

- **Practice incident response**
  *Why*: Regular drills build muscle memory for debugging under pressure.

- **Keep kubectl and tooling versions aligned**
  *Why*: Version skew between client and server can cause unexpected behavior.
