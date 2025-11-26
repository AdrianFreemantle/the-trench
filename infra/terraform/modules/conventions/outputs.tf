output "resource_groups" {
  description = "Standard resource group names"
  value       = local.resource_groups
}

output "names" {
  description = "Standard resource names for core infrastructure"
  value       = local.names
}

output "tags" {
  description = "Default tag set to apply to all Azure resources"
  value       = local.tags
}

output "subnets" {
  description = "Standard subnet names inside VNets"
  value       = local.subnets
}

output "dns_zones" {
  description = "DNS zone domain names for private endpoints"
  value       = local.dns_zones
}
