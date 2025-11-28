###############################################
# Azure Container Registry (ACR)
#
# Phase 1.5 objective:
# Stand up a minimal ACR instance so we can push
# images from CI and manually during development.
#
# Notes:
# - Basic SKU keeps cost low.
# - Public network access remains enabled until
#   private endpoints and firewall routing exist.
# - Admin user is temporarily enabled for ease of
#   testing and will be disabled in a later phase.
# - No retention or hardening rules applied yet.
###############################################
resource "azurerm_container_registry" "acr" {
  name                = module.conventions.names.acr
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location

  sku           = "Basic"
  admin_enabled = true   # Temporary for Phase 1 only

  public_network_access_enabled = true

  # This may require azurerm >= 4.4.0.
  # Remove if your provider version errors on plan.
  anonymous_pull_enabled = false

  tags = module.conventions.tags
}

###############################################
# Outputs
# Helpful for debugging and future CI/CD steps.
###############################################
output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
