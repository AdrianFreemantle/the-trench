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
