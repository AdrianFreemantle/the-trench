###############################################
# Terraform backend configuration
#
# Uses a local backend to avoid:
# - creating a storage account before infra exists
# - dealing with remote state locking during bootstrapping
#
# State is stored outside the env/ directory so that:
# - it does not clutter the module
# - it can be gitignored globally
# - migration to an Azure Storage backend is simpler
#
# NOTE:
# Do not manually move or edit this file once Terraform
# has initialized. Switching backend types requires a
# deliberate state migration.
###############################################
terraform {
  backend "local" {
    path = "../../../.terraform-state/dev.tfstate"
  }
}
