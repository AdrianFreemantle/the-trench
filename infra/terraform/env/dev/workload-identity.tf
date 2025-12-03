###############################################
# Workload Identity for AKS applications
#
# Creates User Assigned Managed Identities and
# Federated Identity Credentials so pods can
# authenticate to Azure resources without secrets.
#
# Flow:
# Pod → K8s ServiceAccount → Federated Credential
#     → Entra Managed Identity → Azure RBAC Role
###############################################

###############################################
# Kubernetes namespace for application workloads
# All app services deploy here.
###############################################
locals {
  app_namespace = "tinyshop"
}

###############################################
# catalog-api identity
#
# Needs access to:
# - Key Vault (secrets)
# - Postgres (catalog database)
###############################################
resource "azurerm_user_assigned_identity" "catalog_api" {
  name                = "${module.conventions.names.aks_cluster}-catalog-api"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = module.conventions.tags
}

resource "azurerm_federated_identity_credential" "catalog_api" {
  name                = "catalog-api-federated"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.catalog_api.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject  = "system:serviceaccount:${local.app_namespace}:catalog-api"
}

###############################################
# orders-api identity
#
# Needs access to:
# - Key Vault (secrets)
# - Postgres (orders database)
# - Service Bus (send messages)
###############################################
resource "azurerm_user_assigned_identity" "orders_api" {
  name                = "${module.conventions.names.aks_cluster}-orders-api"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = module.conventions.tags
}

resource "azurerm_federated_identity_credential" "orders_api" {
  name                = "orders-api-federated"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.orders_api.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject  = "system:serviceaccount:${local.app_namespace}:orders-api"
}

###############################################
# order-worker identity
#
# Needs access to:
# - Key Vault (secrets)
# - Service Bus (receive messages)
# - Cosmos DB via configuration from Key Vault (no direct Azure identity to the database)
###############################################
resource "azurerm_user_assigned_identity" "order_worker" {
  name                = "${module.conventions.names.aks_cluster}-order-worker"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = module.conventions.tags
}

resource "azurerm_federated_identity_credential" "order_worker" {
  name                = "order-worker-federated"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.order_worker.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject  = "system:serviceaccount:${local.app_namespace}:order-worker"
}

###############################################
# Key Vault RBAC - Secrets User
#
# All workloads need to read secrets from Key Vault.
# Key Vault Secrets User allows:
# - Get secrets
# - List secrets
###############################################
resource "azurerm_role_assignment" "catalog_api_kv_secrets" {
  scope                = azurerm_key_vault.core.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.catalog_api.principal_id
}

resource "azurerm_role_assignment" "orders_api_kv_secrets" {
  scope                = azurerm_key_vault.core.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.orders_api.principal_id
}

resource "azurerm_role_assignment" "order_worker_kv_secrets" {
  scope                = azurerm_key_vault.core.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.order_worker.principal_id
}

###############################################
# Service Bus RBAC
#
# orders-api: sends OrderPlaced messages
# order-worker: receives OrderPlaced messages
###############################################
resource "azurerm_role_assignment" "orders_api_sb_sender" {
  scope                = azurerm_servicebus_queue.orders.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.orders_api.principal_id
}

resource "azurerm_role_assignment" "order_worker_sb_receiver" {
  scope                = azurerm_servicebus_queue.orders.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.order_worker.principal_id
}

###############################################
# Outputs for Kubernetes manifest generation
#
# These client IDs are needed in K8s ServiceAccount
# annotations to complete the Workload Identity binding.
###############################################
output "workload_identity_client_ids" {
  description = "Client IDs for workload identity ServiceAccount annotations"
  value = {
    catalog_api  = azurerm_user_assigned_identity.catalog_api.client_id
    orders_api   = azurerm_user_assigned_identity.orders_api.client_id
    order_worker = azurerm_user_assigned_identity.order_worker.client_id
  }
}

output "workload_identity_tenant_id" {
  description = "Tenant ID for workload identity configuration"
  value       = var.tenant_id
}
