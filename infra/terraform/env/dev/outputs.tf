###############################################
# naming_preview
# Exposes all standardized resource names defined
# in the conventions module. Useful for:
# - sanity checking naming conventions
# - verifying environment suffixes
# - interactive debugging during early phases
###############################################
output "naming_preview" {
  value = module.conventions.names
}

###############################################
# resource_group_names
# Returns the three primary resource groups created
# in Phase 1:
# - core: shared infra (ACR, KV, SB, Firewall, hub VNet)
# - data: stateful services (Postgres, PE for data)
# - aks: AKS cluster and spoke VNet
#
# Useful when other stacks/modules need to target
# these RGs explicitly.
###############################################
output "resource_group_names" {
  value = {
    core = azurerm_resource_group.core.name
    data = azurerm_resource_group.data.name
    aks  = azurerm_resource_group.aks.name
  }
}
