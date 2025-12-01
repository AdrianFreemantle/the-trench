###############################################
# Azure Container Registry (ACR)
#
# Minimal ACR instance used to push images from CI
# and manual development workflows.
#
# Notes:
# - Basic SKU keeps cost low.
# - Public network access remains enabled until
#   private endpoints and firewall routing exist.
# - Admin user is temporarily enabled for ease of
#   testing and should be disabled once federated
#   CI authentication is in place.
# - No retention or hardening rules applied yet.
###############################################
resource "azurerm_container_registry" "acr" {
  name                = module.conventions.names.acr
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location

  sku           = "Basic"
  admin_enabled = true # Temporary; disable once federated CI auth is in place

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
