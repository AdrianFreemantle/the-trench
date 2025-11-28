###############################################
# Public IP for Azure Firewall
# Required so the firewall has a static outbound public address,
# even though the AKS cluster and workloads will be private.
###############################################
resource "azurerm_public_ip" "firewall_pip" {
  name                = module.conventions.names.firewall_pip
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location

  # Azure Firewall requires Static allocation and Standard SKU
  allocation_method = "Static"
  sku               = "Standard"

  tags = module.conventions.tags
}

resource "azurerm_public_ip" "firewall_mgmt_pip" {
  name                = module.conventions.names.firewall_mgmt_pip
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location

  allocation_method = "Static"
  sku               = "Standard"

  tags = module.conventions.tags
}

###############################################
# Azure Firewall in the hub VNet
# Deployed into AzureFirewallSubnet. This will become the
# central egress control point once UDRs are configured
# in a later phase.
###############################################
resource "azurerm_firewall" "hub" {
  name                = module.conventions.names.firewall
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  # Firewall running inside a VNet
  sku_name = "AZFW_VNet"
  sku_tier = "Basic" # Cost conscious choice for a lab

  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = azurerm_subnet.hub_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  management_ip_configuration {
    name                 = "firewall-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.hub_firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.firewall_mgmt_pip.id
  }

  tags = module.conventions.tags
}

###############################################
# Application rule collection for AKS control plane
# and ACR outbound traffic using FQDN tags.
#
# Notes:
# - This expresses the "intended" allow list for AKS egress.
# - It only becomes effective once UDRs send spoke traffic
#   through this firewall.
# - When using fqdn_tags, no protocol block is defined here.
###############################################
resource "azurerm_firewall_application_rule_collection" "aks_outbound" {
  name                = "aks-outbound"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.core.name

  # Lower number = higher priority
  priority = 100
  action   = "Allow"

  rule {
    name = "aks-control-plane-and-acr"

    # Source: AKS spoke VNet address space
    source_addresses = [
      "10.1.0.0/16",
    ]

    # FQDN tags cover AKS control plane and ACR endpoints.
    fqdn_tags = [
      "AzureKubernetesService",
      "AzureContainerRegistry",
    ]
  }
}

###############################################
# TEMPORARY network rule collection that allows
# all outbound traffic from the spoke VNet.
#
# This is a safety net while the platform is being
# brought up. It MUST be removed or tightened once:
# - AKS is provisioned
# - required destinations are known
# - UDRs are in place and tested
###############################################
resource "azurerm_firewall_network_rule_collection" "temporary_allow_all" {
  name                = "temporary-allow-all"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.core.name

  # Lower priority than specific app rules, but still high.
  priority = 200
  action   = "Allow"

  rule {
    name = "allow-all-outbound-from-spoke"

    # Source: AKS spoke VNet address space
    source_addresses = [
      "10.1.0.0/16",
    ]

    # Any destination, any port. This is intentionally broad and temporary.
    destination_addresses = [
      "*",
    ]

    destination_ports = [
      "1-65535",
    ]

    protocols = [
      "Any",
    ]
  }
}
