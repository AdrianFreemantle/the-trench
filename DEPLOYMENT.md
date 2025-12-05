# End-to-End Deployment Guide

This document describes the full deployment sequence for the `cloud-native-aks-lab` environment, from Terraform plan/apply through to Kubernetes workloads and ArgoCD.

> **Assumptions**
>
> - You are using the **dev** environment (`infra/terraform/env/dev`).
> - You have the Azure CLI installed and are logged in with sufficient permissions.
> - You are running commands from a Linux/macOS shell or WSL on the jump host unless noted otherwise.
>
> Adjust paths if your working directory differs.

---

## 1. Terraform: Provision Azure Infrastructure

All Azure resources (RGs, VNets, AKS, ACR, PaaS, firewall, etc.) are managed via Terraform under `infra/terraform/env/dev`.

### 1.1 Authenticate with Azure

```bash
az login --use-device-code
az account set --subscription "<SUBSCRIPTION_ID>"
```

Confirm the subscription matches the values used in `dev.auto.tfvars` / `dev.secrets.tfvars`.

### 1.2 Initialize Terraform (first time or after provider changes)

From the repo root or `infra/terraform/env/dev`:

```bash
cd infra/terraform/env/dev
terraform init
```

### 1.3 Validate configuration (optional but recommended)

```bash
terraform validate
```

You should see:

```text
Success! The configuration is valid.
```

### 1.4 Plan changes

```bash
terraform plan \
  -var-file="dev.auto.tfvars" \
  -var-file="dev.secrets.tfvars"
```

Review the plan carefully. Key items to confirm:

- AKS cluster `trench-aks-cluster-dev` in `southafricanorth`.
- Three node pools:
  - `system` (default, `Standard_D2s_v3`, 1 node, taint `CriticalAddonsOnly=true:NoSchedule`)
  - `apps` (user, `Standard_D2s_v3`, autoscale 1–2 nodes, taint `workload=apps:NoSchedule`)
  - `platform` (user, `Standard_D2s_v3`, autoscale 1–2 nodes, taint `workload=platform:NoSchedule`)
- ACR, VNets, firewall, PaaS resources created as expected.

### 1.5 Apply changes

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var-file="dev.secrets.tfvars"
```

Type `yes` when prompted. Provisioning may take several minutes.

**Checkpoint:**

- AKS cluster and node pools are provisioned.
- Networking (hub/spoke, firewall, UDR) is configured.
- ACR and PaaS resources (e.g., Postgres, Service Bus) exist.

---

## 2. Access the AKS Cluster

The AKS cluster is private; access is via the jump host.

### 2.1 Connect to the jump host

The jump host provides access to the private AKS cluster. You can connect directly via SSH or set up a SOCKS proxy for local browser access to cluster services.

#### Option A: Direct SSH connection

From your local machine:

```bash
ssh <jump-host-user>@<jump-host-ip>
```

(Use the username and IP configured in `dev.auto.tfvars` / `dev.secrets.tfvars`.)

#### Option B: SSH with SOCKS proxy (for local browser access)

Create a SOCKS proxy tunnel to access cluster services from your local browser:

```bash
ssh -D 8080 -C <jump-host-user>@<jump-host-ip>
```

**Parameters:**
- `-D 8080`: Creates a SOCKS proxy on local port 8080.
- `-C`: Enables compression.

**Configure your browser:**

1. Set SOCKS proxy to `localhost:8080` (SOCKS5).
2. Access cluster services via their internal IPs or DNS names.

**Example (Firefox):**
- Settings → Network Settings → Manual proxy configuration
- SOCKS Host: `localhost`, Port: `8080`, SOCKS v5

Keep the SSH session running while using the proxy. Press `Ctrl+C` to terminate.

### 2.2 Clone the repository on the jump host

After connecting to the jump host, clone the repository:

```bash
git clone https://github.com/AdrianFreemantle/the-trench.git
cd the-trench
```

### 2.3 Configure kubectl context and run basic checks (runbook)

First, login to Azure:

```bash
az login --use-device-code
az account set --subscription "<SUBSCRIPTION_ID>"
```

From the repo root on the jump host, use the runbook to configure kubectl and print basic cluster information:

```bash
bash ops/runbooks/config-kubectl-dev.sh
```

This script:

- (Optionally) sets the Azure subscription if `SUBSCRIPTION_ID` is provided as an environment variable.
- Calls `az aks get-credentials` for `trench-aks-cluster-dev` in `rg-trench-aks-dev`.
- Shows the current kubectl context and node labels.
- Prints basic AKS cluster metadata (name, version, location, node RG).
- Lists all node pools in a table.
- Shows autoscaler settings for the `apps` and `platform` node pools, including `enableAutoScaling`, `minCount`, `maxCount`, and current node count.
- Shows current Kubernetes nodes

You should see nodes labeled and tainted as follows:

- `agentpool=system` with taint `CriticalAddonsOnly=true:NoSchedule` (AKS system pods only).
- `agentpool=apps`, `workload=apps`, taint `workload=apps:NoSchedule` (application workloads).
- `agentpool=platform`, `workload=platform`, taint `workload=platform:NoSchedule` (observability/infra workloads).

---

## 3. Deploy Ingress and Observability Stack

This step installs:

- NGINX Ingress Controller (internal LoadBalancer).
- kube-prometheus-stack (Prometheus + Grafana).
- Jaeger (distributed tracing).
- OpenTelemetry Collector.

All workloads are scheduled onto the **platform** node pool via `nodeSelector` + `tolerations` in the Helm values.

### 3.1 Run observability deployment runbook

From the repo root on the jump host:

```bash
bash ops/runbooks/deploy-observability-dev.sh
```

The script will:

- Ensure required namespaces exist (e.g., `infra-ingress`, `observability`, `otel-system`).
- Install ingress-nginx using `k8s/infra/helm/ingress-nginx-values.yaml`.
- Install kube-prometheus-stack using `k8s/infra/helm/kube-prometheus-stack-values.yaml`.
- Install Jaeger using `k8s/infra/helm/jaeger-values.yaml`.
- Install OpenTelemetry Collector using `k8s/infra/helm/opentelemetry-collector-values.yaml`.

### 3.2 Verify observability components

```bash
kubectl get pods -n infra-ingress -o wide
kubectl get pods -n observability -o wide
kubectl get pods -n otel-system -o wide
```

You should see pods scheduled on **platform** nodes:

- Ingress controller (`ingress-nginx-controller`).
- Prometheus, Grafana, Jaeger.
- OTEL collector.

Confirm scheduling by checking node column and labels/taints on nodes.

### 3.3 Access observability dashboards

All observability components (Grafana, Prometheus, Jaeger) are exposed via internal Ingress resources using the NGINX Ingress Controller.

#### 3.3.1 Get the Ingress IP

First, get the internal LoadBalancer IP from the NGINX Ingress service:

```bash
kubectl get svc -n infra-ingress ingress-nginx-controller
```

Note the `EXTERNAL-IP` (internal IP in your VNet). This is the same IP used for ArgoCD and other services.

#### 3.3.2 Configure /etc/hosts

On the jump host (or any machine that can reach the internal IP), add entries to `/etc/hosts`:

```bash
INGRESS_IP="<INGRESS_IP_FROM_STEP_3.3.1>"
sudo sh -c "echo \"$INGRESS_IP grafana.trench.internal\" >> /etc/hosts"
sudo sh -c "echo \"$INGRESS_IP prometheus.trench.internal\" >> /etc/hosts"
sudo sh -c "echo \"$INGRESS_IP jaeger.trench.internal\" >> /etc/hosts"
```

#### 3.3.3 Retrieve Grafana admin password

Grafana is deployed with default credentials. The username is `admin` and the password can be retrieved from the Grafana secret:

```bash
kubectl get secret -n observability kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d

echo  # print newline
```

#### 3.3.4 Access the dashboards

From a browser (on a machine that can resolve/reach the internal IP):

- **Grafana**: `http://grafana.trench.internal`
  - Username: `admin`
  - Password: use the value retrieved in step 3.3.3
  - Explore pre-installed Kubernetes dashboards and create custom queries

- **Prometheus**: `http://prometheus.trench.internal`
  - No authentication required (internal only)
  - Use the web UI to explore metrics and run PromQL queries

- **Jaeger**: `http://jaeger.trench.internal`
  - No authentication required (internal only)
  - Use the UI to view distributed traces from instrumented applications

**Note:** If you set up a SOCKS proxy (section 2.1, Option B), configure your local browser to use it, then access these URLs directly from your local machine.

---

## 4. Deploy ArgoCD

ArgoCD is installed into the `argocd` namespace and exposed via an internal Ingress that reuses the NGINX Ingress controller.

### 4.1 Run ArgoCD deployment runbook

From the repo root on the jump host:

```bash
cd ~/the-trench/cloud-native-aks-lab
bash ops/runbooks/deploy-argocd-dev.sh
```

The script will:

- Ensure the `argocd` namespace exists via `k8s/base/infra/argocd/namespace.yaml`.
- Install the ArgoCD Helm chart using `k8s/infra/helm/argocd-values.yaml`.
- Apply the ArgoCD Ingress manifest `k8s/base/infra/argocd/ingress.yaml`.

All ArgoCD components are configured to run on the **platform** node pool.

### 4.2 Verify ArgoCD pods

```bash
kubectl get pods -n argocd -o wide
```

All pods (server, repo-server, application-controller, redis) should be `Running` and scheduled on platform nodes.

### 4.3 Retrieve ArgoCD admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

echo  # print newline
```

If the initial secret has already been consumed/deleted, you can retrieve or reset the password via the `argocd-secret` (see ArgoCD docs), but for fresh installs the `argocd-initial-admin-secret` should be present.

### 4.4 Access the ArgoCD UI

ArgoCD uses the same internal Ingress IP configured in section 3.3.

1. If you haven't already, add an `/etc/hosts` entry for ArgoCD:

   ```bash
   INGRESS_IP="<INGRESS_IP_FROM_SECTION_3.3.1>"
   sudo sh -c "echo \"$INGRESS_IP argocd.trench.internal\" >> /etc/hosts"
   ```

2. In a browser (from a machine that can resolve/reach the internal IP):

   - Navigate to: `http://argocd.trench.internal`.
   - Login with:
     - Username: `admin`.
     - Password: use the value retrieved in step 4.3.

**Note:** If you set up a SOCKS proxy (section 2.1, Option B), configure your local browser to use it, then access this URL directly from your local machine.

---

## 5. Deploy the Demo API Application

The demo FastAPI app is packaged and configured to run in its own namespace with dedicated manifests under `k8s/base/apps/demo-api`.

### 5.1 Ensure image in ACR

The `demo-api` Deployment references an image such as:

```yaml
image: trenchacrcoredev.azurecr.io/demo-api:v1
```

Make sure this image exists in your ACR. If you need to build and push:

On your local dev machine or build agent (with Docker and access to ACR):

```bash
cd apps/demo-api

# Build
docker build -t trenchacrcoredev.azurecr.io/demo-api:v1 .

# Login to ACR
az acr login --name trenchacrcoredev

# Push
docker push trenchacrcoredev.azurecr.io/demo-api:v1
```

### 5.2 Deploy demo-api manifests via Kustomize

From the repo root on the jump host:

```bash
cd ~/the-trench/cloud-native-aks-lab
kubectl apply -k k8s/overlays/dev/apps
```

This applies:

- Base app manifests under `k8s/base/apps/`.
- Dev overlay labels and any environment-specific tweaks under `k8s/overlays/dev/apps/`.

The `demo-api` Deployment specifies:

- Namespace: `demo-api`.
- `nodeSelector: workload: apps` so pods run on the **apps** node pool.
- Liveness/readiness probes on `/health`.
- Service and Ingress for external access.

### 5.3 Verify demo-api

```bash
kubectl get ns demo-api
kubectl get pods -n demo-api -o wide
kubectl get svc -n demo-api
kubectl get ingress -n demo-api
```

Check that:

- The `demo-api` pod is `Running` on an **apps** node.
- The Service is `ClusterIP` and targets the correct port.
- The Ingress routes to the demo host (e.g., `demo.continuecode.com`) using the NGINX Ingress Controller.

If you have DNS set up (or a hosts entry) pointing `demo.continuecode.com` to the NGINX LoadBalancer IP, you can test from a browser:

```text
http://demo.continuecode.com/
http://demo.continuecode.com/health
```

---

## 6. (Optional) Introduce ArgoCD GitOps for the Demo App

Once ArgoCD is running and you have the demo app working via `kubectl apply`, you can move to a GitOps flow (Phase 5.3 in PLAN.md):

1. Create an ArgoCD `Application` manifest pointing at this repo and the `k8s/overlays/dev/apps` path.
2. Apply the Application into the `argocd` namespace.
3. Watch ArgoCD sync the state of the `demo-api` namespace based on Git.

This step is intentionally left as a learning objective; refer to `docs/PLAN.md` and `docs/objectives.md` for guidance when you are ready to implement it.

---

## 7. Tear Down and Rebuild

Because this environment is designed to be ephemeral, you can destroy and recreate it regularly.

### 7.1 Destroy

From `infra/terraform/env/dev`:

```bash
terraform destroy \
  -var-file="dev.auto.tfvars" \
  -var-file="dev.secrets.tfvars"
```

Confirm all resources to be destroyed and type `yes`.

### 7.2 Rebuild

Repeat sections **1–5**:

1. `terraform init` (if needed) and `terraform apply`.
2. Configure AKS credentials on the jump host.
3. Run observability and ArgoCD runbooks.
4. Push app image (if changed) and apply Kustomize overlays for apps.

This gives you a clean, reproducible lab environment each day.
