###############################################
# environment
#
# Controls the suffix applied to all resource names,
# resource groups, DNS zones, and tags.
#
# Supported values in this project:
# - dev
# - test
# - prod
#
# Additional temporary environments (e.g. adrian-dev)
# are allowed but should be removed when not needed.
###############################################
variable "environment" {
  type        = string
  description = "Deployment environment suffix"
  default     = "dev"
}

###############################################
# location
#
# Defines the Azure region where all resources in this
# environment are deployed.
#
# This is intentionally centralized so that AKS, VNets,
# PaaS services, and Private Endpoints all deploy to the
# same region unless explicitly overridden.
###############################################
variable "location" {
  type        = string
  description = "Default Azure region"
  default     = "southafricanorth"
}

###############################################
# Azure subscription and tenant
#
# IDs are not secrets and can safely be passed as
# variables or tfvars. These are required inputs so
# that the azurerm provider does not rely on
# subscription autodetection from the Azure CLI.
###############################################
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for this environment"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID for this environment"
}

variable "postgres_admin_password" {
  type        = string
  description = "Admin password for the dev PostgreSQL Flexible Server"
}

variable "jump_host_admin_username" {
  type        = string
  description = "Admin username for the jump-host VM"
  default     = "azureuser"
}

variable "jump_host_admin_ssh_public_key" {
  type        = string
  description = "SSH public key for the jump-host VM admin user"
}

variable "jump_host_allowed_source_ip" {
  type        = string
  description = "CIDR of the trusted admin IP allowed to SSH to the jump-host VM"
}

###############################################
# Service Bus additional allowed IPs
#
# Optional list of additional public IPs or CIDR ranges
# allowed to access the Service Bus namespace, in
# addition to the Azure Firewall egress IP.
###############################################
variable "service_bus_additional_allowed_ips" {
  type        = list(string)
  description = "Additional public IPs or CIDR ranges allowed to access the Service Bus namespace (for admin/VPN access)."
  default     = []
}

###############################################
# NGINX Ingress LoadBalancer IP
#
# Internal LoadBalancer IP assigned to the NGINX
# Ingress Controller. Used for DNS A records pointing
# to internal cluster services (Grafana, Prometheus, etc.).
# Obtain this IP after deploying NGINX Ingress via Helm.
###############################################
variable "nginx_ingress_lb_ip" {
  description = "Internal LoadBalancer IP for NGINX Ingress Controller"
  type        = string
}