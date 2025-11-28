###############################################
# Azure Container Registry
#
# Provides a cost-conscious ACR instance for the
# dev environment. This registry is used by CI
# pipelines to push images that will later be
# consumed by AKS and other consumers.
#
# Phase 1.5 scope:
# - Basic SKU
# - Public network access enabled
# - Admin user enabled for convenience
# - Anonymous pull disabled
# - No geo-replication, retention, or
#   advanced policies yet; these can be
#   introduced in later hardening phases.
###############################################
resource "azurerm_container_registry" "core" {
  name                = module.conventions.names.acr
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location

  sku           = "Basic"
  admin_enabled = true

  public_network_access_enabled = true
  anonymous_pull_enabled        = false

  tags = module.conventions.tags
}
