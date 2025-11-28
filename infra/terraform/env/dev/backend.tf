###############################################
# Terraform backend configuration
#
# Phase 1 uses a local backend. This avoids:
# - creating a storage account too early
# - dealing with remote state locking before infra exists
#
# State is stored outside the env/ directory so that:
# - it does not clutter the module
# - it can be gitignored globally
# - future migration to Azure Storage backend is easier
#
# NOTE:
# Do not manually move or edit this file once Terraform
# has initialized. A remote backend will be introduced
# in a later phase.
###############################################
terraform {
  backend "local" {
    path = "../../../.terraform-state/dev.tfstate"
  }
}
