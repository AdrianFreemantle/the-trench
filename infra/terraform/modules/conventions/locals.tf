locals {
  # Global prefixes
  prefix    = "trench"
  rg_prefix = "rg-trench"

  # Service groups from conventions
  service_groups = {
    aks  = "aks"
    vnet = "vnet"
    fw   = "fw"
    acr  = "acr"
    kv   = "kv"
    pg   = "pg"
    sb   = "sb"
    dns  = "dns"
    pe   = "pe"
    jh   = "jh"
  }

  # Standard resource group names
  resource_groups = {
    core = "${local.rg_prefix}-core-${var.environment}"
    data = "${local.rg_prefix}-data-${var.environment}"
    aks  = "${local.rg_prefix}-aks-${var.environment}"
  }

  # Core resource names for Phase 1
  # trench-<service-group>-<component>-<env>
  names = {
    # VNets
    vnet_hub   = "${local.prefix}-${local.service_groups.vnet}-hub-${var.environment}"
    vnet_spoke = "${local.prefix}-${local.service_groups.vnet}-spoke-${var.environment}"

    # Firewall and public IP
    firewall         = "${local.prefix}-${local.service_groups.fw}-core-${var.environment}"
    firewall_pip     = "${local.prefix}-${local.service_groups.fw}-pip-${var.environment}"
    firewall_mgmt_pip = "${local.prefix}-${local.service_groups.fw}-mgmt-pip-${var.environment}"

    # ACR
    # ACR must use an alphanumeric-only name (no dashes), so this deviates from the default pattern.
    acr = "${local.prefix}${local.service_groups.acr}core${var.environment}"

    # Key Vault
    key_vault = "${local.prefix}-${local.service_groups.kv}-core-${var.environment}"

    # Postgres Flexible
    postgres = "${local.prefix}-${local.service_groups.pg}-flex-${var.environment}"

    # Service Bus
    service_bus = "${local.prefix}-${local.service_groups.sb}-core-${var.environment}"

    # AKS cluster
    aks_cluster = "${local.prefix}-${local.service_groups.aks}-cluster-${var.environment}"

    log_analytics = "${local.prefix}-log-core-${var.environment}"

    # Private endpoints
    pe_kv = "${local.prefix}-${local.service_groups.pe}-kv-${var.environment}"
    pe_pg = "${local.prefix}-${local.service_groups.pe}-pg-${var.environment}"
    pe_sb = "${local.prefix}-${local.service_groups.pe}-sb-${var.environment}"
    jump_host_vm  = "${local.prefix}-${local.service_groups.jh}-vm-${var.environment}"
    jump_host_pip = "${local.prefix}-${local.service_groups.jh}-pip-${var.environment}"
    jump_host_nic = "${local.prefix}-${local.service_groups.jh}-nic-${var.environment}"
    jump_host_nsg = "${local.prefix}-${local.service_groups.jh}-nsg-${var.environment}"
  }

  # Subnet names inside VNets
  # Note: AzureFirewallSubnet name is mandatory
  subnets = {
    hub_firewall            = "AzureFirewallSubnet"
    hub_firewall_mgmt       = "AzureFirewallManagementSubnet"
    hub_shared_services     = "shared-services"
    spoke_aks_nodes         = "aks-nodes"
    spoke_private_endpoints = "private-endpoints"
  }

  # Private DNS zone domain names (actual DNS zone names)
  dns_zones = {
    kv = "privatelink.vaultcore.azure.net"
    pg = "privatelink.postgres.database.azure.com"
    sb = "privatelink.servicebus.windows.net"
  }

  # Default tags for all resources
  tags = {
    owner       = var.owner
    environment = var.environment
    cost-center = var.cost_center
    purpose     = "core"
  }
}
