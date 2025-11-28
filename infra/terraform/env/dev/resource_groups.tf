###############################################
# Core resource group
# Holds shared foundational services for the entire platform:
# - ACR
# - Key Vault
# - Service Bus
# - Azure Firewall
# - Hub VNet
# These resources are shared across AKS and data services.
###############################################
resource "azurerm_resource_group" "core" {
  name     = module.conventions.resource_groups.core
  location = var.location
  tags     = module.conventions.tags
}

###############################################
# Data resource group
# Dedicated to stateful data services and their private endpoints:
# - Postgres Flexible Server
# - Private Endpoints for Postgres
# Designed for clearer cost tracking and future lifecycle separation.
###############################################
resource "azurerm_resource_group" "data" {
  name     = module.conventions.resource_groups.data
  location = var.location
  tags     = module.conventions.tags
}

###############################################
# AKS resource group
# Holds AKS cluster and AKS-specific networking:
# - AKS managed cluster resource
# - Spoke VNet
# - Subnets (aks-nodes, private-endpoints)
# This RG does *not* contain shared infra or data services.
###############################################
resource "azurerm_resource_group" "aks" {
  name     = module.conventions.resource_groups.aks
  location = var.location
  tags     = module.conventions.tags
}
