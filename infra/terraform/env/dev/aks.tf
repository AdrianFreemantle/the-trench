###############################################
# AKS Cluster - dev
#
# Implements PLAN step 1.6:
# - Private AKS cluster in rg-trench-aks-dev
# - Attached to spoke VNet aks-nodes subnet
# - RBAC + OIDC issuer + Workload Identity
# - Separate system and user node pools
# - Integrated with ACR via role assignment
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
  # System assigned managed identity is used for:
  # - pulling from ACR (AcrPull role)
  # - future role assignments to Key Vault, etc.
  ###########################################
  identity {
    type = "SystemAssigned"
  }

  ###########################################
  # API server and workload identity
  # - Private only API endpoint
  # - OIDC issuer required for workload identity
  ###########################################
  private_cluster_enabled   = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  ###########################################
  # Networking
  # - Azure CNI in existing VNet
  # - Node pool attached to aks-nodes subnet
  ###########################################
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  ###########################################
  # System node pool
  # - Single small node for cluster system workloads
  # - Application workloads go to separate pool
  ###########################################
  default_node_pool {
    name           = "system"
    vm_size        = "Standard_D2s_v5"
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.spoke_aks_nodes.id
    type           = "VirtualMachineScaleSets"
  }

  tags = module.conventions.tags
}

###############################################
# User Node Pool
#
# Dedicated pool for application workloads.
# System services stay on the default "system" pool.
###############################################
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  vm_size        = "Standard_D2s_v5"
  node_count     = 1
  vnet_subnet_id = azurerm_subnet.spoke_aks_nodes.id

  mode = "User"

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
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
