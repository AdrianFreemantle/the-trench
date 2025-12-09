###############################################
# Private DNS Zone for AKS API Server
#
# Required so both hub VNet (jump host) and spoke VNet
# can resolve the private AKS API server FQDN.
###############################################
resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.aks.name

  tags = module.conventions.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks_hub" {
  name                  = "aks-hub-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks_spoke" {
  name                  = "aks-spoke-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

###############################################
# User Assigned Identity for AKS
#
# Required when using a custom private DNS zone.
# AKS needs permissions to manage DNS records.
###############################################
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${module.conventions.names.aks_cluster}-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  tags = module.conventions.tags
}

resource "azurerm_role_assignment" "aks_dns_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.spoke.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

###############################################
# AKS cluster
#
# Private, RBAC-enabled AKS cluster:
# - Attached to spoke VNet aks-nodes subnet
# - OIDC issuer + Workload Identity enabled
# - Uses Azure CNI in the spoke VNet
# - Pulls images from ACR via role assignment
###############################################
resource "azurerm_kubernetes_cluster" "aks" {
  name                = module.conventions.names.aks_cluster
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  # DNS prefix for the cluster (AKS-managed DNS)
  dns_prefix = "trench-aks-dev"

  # Free control plane tier is sufficient for this lab
  sku_tier = "Free"

  ###########################################
  # Identity
  # User assigned identity is required when using
  # a custom private DNS zone. It has permissions for:
  # - Private DNS Zone Contributor on AKS DNS zone
  # - Network Contributor on spoke VNet
  ###########################################
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  ###########################################
  # Key Vault secrets provider (CSI driver)
  # Enables the azure-keyvault-secrets-provider
  # add-on for mounting Key Vault secrets via CSI.
  ###########################################
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2h"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.core.id
  }

  ###########################################
  # API server and workload identity
  # - Private only API endpoint
  # - OIDC issuer required for workload identity
  ###########################################
  private_cluster_enabled   = true
  private_dns_zone_id       = azurerm_private_dns_zone.aks.id
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  ###########################################
  # Networking
  # - Azure CNI in existing VNet
  # - Node pool attached to aks-nodes subnet
  ###########################################
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
  }

  ###########################################
  # System node pool
  # - Single small node for cluster system workloads
  # - Tainted CriticalAddonsOnly per Microsoft best practice
  # - Application workloads go to separate pool
  ###########################################
  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D2s_v3"
    node_count                   = 1
    vnet_subnet_id               = azurerm_subnet.spoke_aks_nodes.id
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true
  }

  tags = module.conventions.tags

  # Dependencies:
  # - UDR must be associated with subnet before AKS can use userDefinedRouting
  # - Role assignments must exist before AKS can use the custom private DNS zone
  depends_on = [
    azurerm_subnet_route_table_association.aks_nodes,
    azurerm_role_assignment.aks_dns_contributor,
    azurerm_role_assignment.aks_network_contributor
  ]
}

###############################################
# User Node Pools
#
# Dedicated pools for application and platform workloads.
# System services stay on the default "system" pool.
###############################################
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  vm_size        = "Standard_D2s_v3"
  vnet_subnet_id = azurerm_subnet.spoke_aks_nodes.id
  mode           = "User"
  auto_scaling_enabled = true
  min_count            = 1
  max_count            = 2

  node_labels = {
    workload = "apps"
  }

  node_taints = [
    "workload=apps:NoSchedule",
  ]

  tags = module.conventions.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "platform" {
  name                  = "platform"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  vm_size        = "Standard_D2s_v3"
  vnet_subnet_id = azurerm_subnet.spoke_aks_nodes.id
  mode           = "User"
  auto_scaling_enabled = true
  min_count            = 1
  max_count            = 2

  node_labels = {
    workload = "platform"
  }

  node_taints = [
    "workload=platform:NoSchedule",
  ]

  tags = module.conventions.tags
}

###############################################
# ACR Pull Permissions for AKS
#
# Grants the AKS managed identity permission to
# pull images from trench-acr-core-dev.
###############################################
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
