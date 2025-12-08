# Phase 6.2 Plan – catalog-api

This document captures the implementation plan for **Phase 6.2: Catalog API (Postgres integration)**, including manual Workload Identity setup for `catalog-api`.

The focus is on **data flow, identity, connectivity, and GitOps**, not on rich business features.

---

## 1. Service scope recap

**Service:** `catalog-api`

**Purpose:**
- Serve product data to `shop-ui` and `orders-api`.

**Responsibilities:**
- Store and expose a minimal `products` catalog.
- Provide:
  - `GET /products`
  - `GET /products/{id}`

**Tech stack (planned):**
- Node.js 20
- Express or Fastify
- Azure Postgres Flexible Server (`catalog` database)
- Azure Workload Identity + User Assigned Managed Identity
- OTEL for traces/metrics (added later in Phase 7+)

---

## 2. Target architecture for catalog-api

### Namespaces and ownership

- Each service/domain has its **own namespace**.
- For `catalog-api`:
  - Namespace: `catalog-api`
  - ServiceAccount: `catalog-api`

### Data store

- Existing Postgres Flexible Server:
  - Defined in `infra/terraform/env/dev/paas.tf` as `azurerm_postgresql_flexible_server.core`.
- Databases:
  - `catalog` (for `catalog-api`) – **already provisioned** by Terraform.
  - `orders` (for `orders-api`, later).

### Access pattern

- `catalog-api` pods authenticate to Postgres using **Workload Identity**:
  - Pod → K8s `ServiceAccount` → OIDC token → **User Assigned Managed Identity (UAMI)** → Azure RBAC & Postgres AAD roles.
- No static DB usernames/passwords in app configuration.

---

## 3. Manual Workload Identity setup (catalog-api)

> Intentional: This is done **manually in the Azure Portal** first, before later enabling the Terraform module in `workload-identity.tf.disabled`.

### 3.1 Create User Assigned Managed Identity (UAMI)

In Azure Portal:

1. Go to **Managed Identities → Create**.
2. Use the AKS resource group (e.g. `rg-trench-aks-dev`).
3. Name the identity (example):
   - `trench-aks-catalog-api-dev`
4. After creation, record:
   - **Client ID**
   - **Principal ID**

This identity will be referenced by the `catalog-api` `ServiceAccount` via annotation.

### 3.2 Configure federated credential for catalog-api

Goal: allow the `catalog-api` `ServiceAccount` in the `catalog-api` namespace to obtain tokens as the UAMI.

1. Obtain the AKS OIDC issuer URL (on the jump host):

   ```bash
   az aks show \
     --resource-group rg-trench-aks-dev \
     --name trench-aks-cluster-dev \
     --query "oidcIssuerProfile.issuerUrl" -o tsv
   ```

2. In Portal, open the **User Assigned Managed Identity** from 3.1.
3. Go to **Federated credentials → Add**.
4. Configure:
   - **Issuer:** the OIDC issuer URL from the `az aks show` command.
   - **Subject:**
     - `system:serviceaccount:catalog-api:catalog-api`
       - Namespace: `catalog-api`
       - ServiceAccount: `catalog-api`
   - **Audience:**
     - `api://AzureADTokenExchange`

This is the manual equivalent of the Terraform `azurerm_federated_identity_credential` that is currently in `workload-identity.tf.disabled`.

### 3.3 Grant UAMI access to Postgres

Goal: allow the UAMI to authenticate to, and query, the `catalog` database.

1. Ensure Postgres Flexible Server has an **AAD admin** configured.
2. Using an AAD admin connection (from a trusted host):
   - Connect to the `catalog` DB.
   - Create a contained user for the UAMI:
     - Based on its **object/principal ID**.
   - Grant minimal required permissions (for Phase 6.2):
     - `SELECT` on `products` table (and `INSERT/UPDATE` if you plan to manage data via the API).

Later phases can refine roles and permissions as needed.

---

## 4. Catalog database schema (conceptual)

In Postgres `catalog` database:

- Table: `products`
  - Columns (minimal):
    - `id` (PK, UUID or serial)
    - `name` (text)
    - `description` (text)
    - `price` (numeric)
    - `sku` (optional, text)
    - `stock` (optional, int for lab scenarios)

Schema creation can be done manually (psql/Azure Data Studio) or later via migrations/scripts.

---

## 5. catalog-api application design

### Responsibilities

- Expose read-only endpoints for now:
  - `GET /products` – list products.
  - `GET /products/{id}` – get details for a single product.
- Connect to Postgres `catalog` DB using AAD token obtained via the UAMI.

### Auth / connectivity from the pod

Inside the `catalog-api` container:

- Use Azure SDK for JavaScript/TypeScript or an equivalent token acquisition library:
  - Prefer `DefaultAzureCredential` (or a specific Workload Identity credential type) to obtain an access token for the Postgres resource scope.
- Pass the acquired token into the Postgres client (e.g. `pg` module) via appropriate connection options.
- Use environment variables for:
  - Postgres host / FQDN.
  - Port.
  - Database name (`catalog`).
  - SSL mode.

Implementation details can be finalized when writing the service, but the high-level design is:

1. On startup, create a DB pool using token-based auth.
2. For each request, run simple SQL queries against `products`.

---

## 6. Kubernetes manifests and GitOps wiring

### 6.1 Base manifests (`k8s/base/apps/catalog-api`)

Create a new folder with:

- `namespace.yaml`
  - Namespace definition for `catalog-api`.
- `serviceaccount.yaml`
  - `ServiceAccount` named `catalog-api` in the `catalog-api` namespace.
  - Labels/annotations for workload identity:
    - `azure.workload.identity/use: "true"`
    - `azure.workload.identity/client-id: <client-id-of-UAMI>`
- `deployment.yaml`
  - Deploys the `catalog-api` container image.
  - Uses `serviceAccountName: catalog-api`.
  - Includes env vars for Postgres connection.
  - Schedules to appropriate node pool via `nodeSelector`/`tolerations`.
- `service.yaml`
  - ClusterIP Service for `catalog-api`.
- `ingress.yaml`
  - Ingress definition to expose `catalog-api` via the existing NGINX ingress controller.
- `kustomization.yaml`
  - References the above resources.

### 6.2 Dev overlay (`k8s/overlays/dev/apps`)

- Ensure the dev `apps` overlay includes `catalog-api`.
- Optionally:
  - Add image overrides for `catalog-api` similar to `demo-api` to support CI-driven tag updates later.

### 6.3 ArgoCD Application updates

- Either reuse the existing `demo-api-dev` Application that points to `k8s/overlays/dev/apps`, or adjust/create an ArgoCD `Application` so that `catalog-api` is deployed via GitOps in the same way as `demo-api`.

Result:

- Once manifests are committed and synced, `catalog-api` will run in its own namespace, using the `catalog-api` ServiceAccount, and Workload Identity will connect it to Postgres.

---

## 7. Validation plan

After implementation:

1. **Identity wiring**
   - Exec into a `catalog-api` pod.
   - Confirm that token acquisition via Workload Identity works (e.g. via logs or a small diagnostic endpoint).

2. **Database connectivity**
   - `kubectl port-forward` or call the API through ingress:
     - `GET /products` should return data from the Postgres `catalog` DB.

3. **Network constraints**
   - Verify that connectivity works only via the private endpoint (no public access).

4. **GitOps behavior**
   - Change a non-destructive manifest setting (replica count, label) for `catalog-api`.
   - Confirm ArgoCD sees the change and syncs correctly.

---

## 8. Future alignment with Terraform

Once you are comfortable with manual Workload Identity setup:

- Revisit `infra/terraform/env/dev/workload-identity.tf.disabled` and adapt it to:
  - Create UAMIs and federated credentials per-service (namespaces `catalog-api`, `orders-api`, etc.).
  - Match the manual Portal configuration used for `catalog-api`.
- Enable the file and let Terraform manage identities going forward.
