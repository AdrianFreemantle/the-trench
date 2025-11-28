###############################################
# Terraform and provider requirements
#
# - Terraform 1.8+ is required for stable module behavior
#   and consistent provider interactions.
#
# - azurerm "~> 4.0" pins the provider to the major version
#   4.x range, preventing accidental breaking changes from 5.x.
#
# - provider "azurerm" requires the `features {}` block even
#   if no features are configured. This is a mandatory stub.
###############################################
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

###############################################
# Azure provider using Azure CLI authentication.
# No service principals or credentials are stored locally.
# az login must be executed before running terraform.
###############################################
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
