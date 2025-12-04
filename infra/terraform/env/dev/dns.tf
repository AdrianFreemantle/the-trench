###############################################
# Private DNS Zone for Internal Cluster Services
#
# Custom DNS zone for internal hostnames used by
# cluster services (Grafana, Prometheus, ArgoCD, etc.).
# Linked to both hub and spoke VNets so all VMs
# (jump host, AKS nodes, future VPN clients) can
# resolve these hostnames.
#
# DNS A records for specific services will be added
# after NGINX Ingress LoadBalancer IP is known.
###############################################

# Custom internal DNS zone for cluster services
resource "azurerm_private_dns_zone" "internal" {
  name                = "trench.internal"
  resource_group_name = azurerm_resource_group.aks.name
  tags                = module.conventions.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal_hub" {
  name                  = "internal-hub-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal_spoke" {
  name                  = "internal-spoke-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

###############################################
# DNS A Records for Observability Services
#
# Points internal hostnames to the NGINX Ingress
# Controller's internal LoadBalancer IP.
###############################################
resource "azurerm_private_dns_a_record" "grafana" {
  name                = "grafana"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.aks.name
  ttl                 = 300
  records             = [var.nginx_ingress_lb_ip]
  tags                = module.conventions.tags
}

resource "azurerm_private_dns_a_record" "prometheus" {
  name                = "prometheus"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.aks.name
  ttl                 = 300
  records             = [var.nginx_ingress_lb_ip]
  tags                = module.conventions.tags
}