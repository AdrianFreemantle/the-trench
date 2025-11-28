###############################################
# Conventions module
#
# This module centralizes:
# - naming patterns
# - resource group names
# - subnet names
# - tag sets
# - private DNS zone names
#
# Every resource in this environment must derive its
# names and tags from this module to ensure full
# consistency across the platform.
###############################################
module "conventions" {
  source      = "../../modules/conventions"
  environment = var.environment
}
