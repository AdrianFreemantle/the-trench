# Identity & Secrets Best Practices

Checklist-style guidance for Workload Identity, Managed Identities, and secure secret management in AKS.

---

## 1. Workload Identity Fundamentals

- **Understand the full authentication chain: Pod → ServiceAccount → OIDC token → Entra ID → Managed Identity → Azure Resource**
  *Why*: This is how a pod proves its identity to Azure services without storing credentials. The pod's ServiceAccount is federated with an Entra ID app registration, allowing token exchange.

- **Prefer Workload Identity over legacy AAD Pod Identity**
  *Why*: Workload Identity uses Kubernetes-native constructs (ServiceAccount tokens), eliminates the NMI/MIC pods, removes network dependencies, and has no IMDS IP blocking issues.

- **Know the weaknesses of the old AAD Pod Identity model**
  *Why*: AAD Pod Identity required additional infrastructure (NMI DaemonSet, MIC deployment), had scaling issues, race conditions during pod startup, and network policy complexity with IMDS blocking.

---

## 2. Managed Identity Types

- **Understand user-assigned vs system-assigned managed identity**
  *Why*: System-assigned MI is tied to the resource lifecycle (created/deleted with the resource). User-assigned MI is independent and can be shared across multiple resources.

- **Use user-assigned managed identity (UAMI) for application workloads**
  *Why*: UAMI can be pre-created with Terraform/IaC, assigned to multiple pods, and survives pod restarts. Easier to manage permissions before the workload exists.

- **Use system-assigned MI for cluster-level operations (kubelet, extensions)**
  *Why*: AKS manages these automatically for cluster operations like pulling images from ACR or accessing Azure resources.

- **Consider one UAMI per logical application or bounded context**
  *Why*: Provides least-privilege boundaries—each app only has access to its required resources. Avoid one mega-identity with broad permissions.

---

## 3. Workload Identity Configuration

- **Create a federated credential linking ServiceAccount to UAMI**
  *Why*: This is the trust relationship that allows the ServiceAccount's OIDC token to be exchanged for an Entra ID token.

```yaml
# ServiceAccount with Workload Identity annotations
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    azure.workload.identity/client-id: "<UAMI-CLIENT-ID>"
  labels:
    azure.workload.identity/use: "true"
```

- **Inject identity into pods using labels**
  *Why*: The `azure.workload.identity/use: "true"` label triggers the Workload Identity webhook to inject environment variables and projected token volumes.

- **Scope federated credentials to specific namespaces and ServiceAccounts**
  *Why*: Prevents unauthorized pods from impersonating the identity. The federation specifies exact namespace:serviceaccount pairs.

---

## 4. Least Privilege for Identities

- **Grant only the minimum Azure RBAC roles required**
  *Why*: A pod that only reads from Key Vault should have "Key Vault Secrets User", not "Contributor". Limit blast radius.

- **Use custom roles when built-in roles are too broad**
  *Why*: Built-in roles like "Storage Blob Data Contributor" may grant more actions than needed for a specific use case.

- **Scope role assignments to the specific resource, not resource group or subscription**
  *Why*: Grant access to the exact Key Vault, Storage Account, or Service Bus namespace rather than everything in the RG.

- **Avoid cluster-wide identities that can access all namespaces' secrets**
  *Why*: Each namespace/team should have its own identity with access only to its resources.

---

## 5. Key Vault Integration

- **Use Secrets Store CSI Driver for mounting Key Vault secrets**
  *Why*: Secrets are fetched at pod startup and optionally synced as Kubernetes Secrets. No secrets stored in Git or etcd until pod mount.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMUserAssignedIdentity: "false"
    clientID: "<UAMI-CLIENT-ID>"
    keyvaultName: "<KEYVAULT-NAME>"
    tenantId: "<TENANT-ID>"
    objects: |
      array:
        - |
          objectName: my-secret
          objectType: secret
```

- **Understand CSI driver vs synced Kubernetes Secrets trade-offs**
  *Why*: CSI-only mounting means secrets never exist as K8s Secrets (more secure), but some apps/frameworks expect environment variables or K8s Secret volumes. Syncing creates K8s Secrets that persist in etcd.

- **Enable sync as Kubernetes Secret only when required by application design**
  *Why*: If your app can read from a mounted file path, avoid syncing. If it needs env vars, use `secretObjects` to sync.

---

## 6. Secret Rotation Without Downtime

- **Enable auto-rotation in Secrets Store CSI Driver**
  *Why*: The driver can poll Key Vault at intervals and update mounted secrets without pod restarts.

```yaml
# Helm values for secrets-store-csi-driver
enableSecretRotation: true
rotationPollInterval: 2m
```

- **Design applications to reload secrets without restart**
  *Why*: For secrets like database passwords that change, apps should either re-read the file periodically or use file system watchers.

- **Use staged secret rotation: add new version, deploy, remove old**
  *Why*: Both old and new secrets should be valid during rotation. Update Key Vault with new value, let pods pick it up, then disable old version.

- **For database credentials, use Key Vault rotation with Azure Functions**
  *Why*: Azure provides built-in rotation functions for SQL, Storage, and other services that update both the service and Key Vault atomically.

---

## 7. Preventing Identity Lateral Movement

- **Use separate ServiceAccounts per deployment, not a shared default**
  *Why*: The default ServiceAccount in a namespace should not have any federated credentials. Each workload gets its own SA.

- **Block pods from using the default ServiceAccount with Azure identities**
  *Why*: Use admission policies to require explicit ServiceAccount selection for workloads needing Azure access.

- **Audit which pods have access to which Azure resources**
  *Why*: Regularly review identity assignments and ensure they match expected workload boundaries.

- **Use NetworkPolicy to prevent pods from accessing IMDS if not needed**
  *Why*: Block 169.254.169.254 for namespaces that should not use any managed identity, preventing accidental credential leakage.

---

## 8. Kubernetes Secrets Security

- **Enable etcd encryption at rest for Kubernetes Secrets**
  *Why*: By default, Secrets in AKS etcd are encrypted, but verify this is enabled for your cluster configuration.

- **Limit RBAC access to Secrets**
  *Why*: Only pods and service accounts that need specific secrets should have `get`, `list`, or `watch` permissions on them.

- **Avoid embedding secrets in ConfigMaps or deployment manifests**
  *Why*: ConfigMaps are not designed for sensitive data and have different access controls than Secrets.

- **Never log secrets or include them in error messages**
  *Why*: Secrets in logs persist and can be accessed by anyone with log access.

---

## 9. External Secrets Operator (Alternative Pattern)

- **Consider External Secrets Operator for GitOps-friendly secret management**
  *Why*: ESO syncs secrets from Key Vault (or other backends) into K8s Secrets declaratively, fitting GitOps workflows.

- **Use ExternalSecret CRDs to define which secrets to sync**
  *Why*: Keeps secret references in Git while actual values come from Key Vault at runtime.

- **Compare ESO vs CSI Driver based on your needs**
  *Why*: CSI Driver mounts secrets per-pod and supports rotation without K8s Secrets. ESO creates K8s Secrets cluster-wide but integrates better with Helm/Kustomize expecting Secret references.

---

## 10. Diagnosing Identity Issues

- **Check pod logs for AZURE_FEDERATED_TOKEN_FILE presence**
  *Why*: Workload Identity webhook injects this env var. If missing, the webhook didn't process the pod.

- **Verify ServiceAccount has correct annotations and labels**
  *Why*: Both `azure.workload.identity/client-id` annotation and `azure.workload.identity/use: "true"` label are required.

- **Test token exchange with Azure CLI inside the pod**
  *Why*: Run `az login --federated-token` to verify the token exchange works before troubleshooting application code.

- **Check federated credential configuration in Entra ID**
  *Why*: The issuer URL must match your AKS OIDC issuer, and the subject must match `system:serviceaccount:<namespace>:<sa-name>`.

---

## 11. Design Principles for Identity

- **Treat identity as infrastructure, not application config**
  *Why*: Create UAMIs and federated credentials via Terraform/IaC alongside the infrastructure, not ad-hoc.

- **One identity per trust boundary**
  *Why*: Each microservice or bounded context should have its own identity with access only to its resources.

- **Prefer short-lived tokens over long-lived credentials**
  *Why*: Workload Identity tokens expire and are automatically refreshed. Avoid storing any long-lived keys.

- **Audit and review identity assignments regularly**
  *Why*: Access requirements change over time. Remove unused identities and reduce scope as systems evolve.
