###############################################
# naming_preview
# Exposes all standardized resource names defined
# in the conventions module. Useful for:
# - sanity checking naming conventions
# - verifying environment suffixes
# - interactive debugging during initial setup
###############################################
output "naming_preview" {
  value = module.conventions.names
}

###############################################
# resource_group_names
# Returns the three primary resource groups for this environment:
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

output "jump_host_public_ip" {
  description = "Public IP address of the jump-host VM for SSH access"
  value       = azurerm_public_ip.jump_host.ip_address
}

output "firewall_public_ip" {
  description = "Azure Firewall data-plane public IP (egress IP for AKS)"
  value       = azurerm_public_ip.firewall_pip.ip_address
}

output "aks_cluster_name" {
  description = "AKS cluster name for az aks get-credentials"
  value       = azurerm_kubernetes_cluster.aks.name
}
