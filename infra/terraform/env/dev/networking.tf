###############################################
# Hub VNet
# Central network domain for shared infrastructure:
# - Azure Firewall
# - Shared services subnet (future add ons)
# - Private DNS resolver (optional future)
#
# All traffic from the spoke (AKS) will ultimately transit
# through this VNet once UDRs are configured.
###############################################
resource "azurerm_virtual_network" "hub" {
  name                = module.conventions.names.vnet_hub
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = module.conventions.tags
}

###############################################
# Spoke VNet
# Dedicated network for AKS cluster and all workload private endpoints.
# This VNet intentionally contains only app-facing infrastructure.
###############################################
resource "azurerm_virtual_network" "spoke" {
  name                = module.conventions.names.vnet_spoke
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = module.conventions.tags
}

###############################################
# Hub subnets
# AzureFirewallSubnet is mandatory for Azure Firewall.
# shared-services is for optional future components like:
# - DNS forwarders
# - monitoring agents
# - other hub-side shared infrastructure
###############################################
resource "azurerm_subnet" "hub_firewall" {
  name                 = module.conventions.subnets.hub_firewall
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "hub_firewall_mgmt" {
  name                 = module.conventions.subnets.hub_firewall_mgmt
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "hub_shared_services" {
  name                 = module.conventions.subnets.hub_shared_services
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

###############################################
# Spoke subnets
# aks-nodes holds the AKS node pool.
# private-endpoints is where Key Vault, Postgres, and
# Service Bus private endpoints will live.
###############################################
resource "azurerm_subnet" "spoke_aks_nodes" {
  name                 = module.conventions.subnets.spoke_aks_nodes
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "spoke_private_endpoints" {
  name                 = module.conventions.subnets.spoke_private_endpoints
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.1.0/24"]
}

###############################################
# VNet Peering: Hub -> Spoke
# Allows traffic from hub infrastructure into the spoke VNet.
# Forwarded traffic is enabled to support firewall routing later.
###############################################
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = azurerm_resource_group.core.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.hub,
    azurerm_virtual_network.spoke
  ]
}

###############################################
# VNet Peering: Spoke -> Hub
# Allows AKS workloads to reach hub services such as:
# - Azure Firewall (future forced egress)
# - ACR, KV, PG, SB via Private Endpoints
###############################################
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = azurerm_resource_group.aks.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.spoke,
    azurerm_virtual_network.hub
  ]
}

resource "azurerm_route_table" "aks_nodes" {
  name                = "rt-aks-nodes-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }

  tags = module.conventions.tags
}

resource "azurerm_subnet_route_table_association" "aks_nodes" {
  subnet_id      = azurerm_subnet.spoke_aks_nodes.id
  route_table_id = azurerm_route_table.aks_nodes.id
}

###############################################
# Outputs
# Useful for debugging, cross module references,
# or feeding into future modules if needed.
###############################################
output "vnet_ids" {
  value = {
    hub   = azurerm_virtual_network.hub.id
    spoke = azurerm_virtual_network.spoke.id
  }
}
