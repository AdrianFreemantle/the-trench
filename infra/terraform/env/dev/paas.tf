###############################################
# Azure Key Vault - core
###############################################
resource "azurerm_key_vault" "core" {
  name                = module.conventions.names.key_vault
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  sku_name = "standard"

  tenant_id = var.tenant_id

  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = false

  # RBAC-only access model (access policies not used)
  rbac_authorization_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = module.conventions.tags
}

###############################################
# PostgreSQL Flexible Server - data
###############################################
resource "azurerm_postgresql_flexible_server" "core" {
  name                   = module.conventions.names.postgres
  location               = var.location
  resource_group_name    = azurerm_resource_group.data.name
  zone                   = "1"
  administrator_login    = "pgadmin"
  administrator_password = var.postgres_admin_password

  sku_name = "B_Standard_B1ms"

  public_network_access_enabled = false

  storage_mb = 32768
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  version = "16"

  tags = module.conventions.tags
}

# Application databases
resource "azurerm_postgresql_flexible_server_database" "catalog" {
  name      = "catalog"
  server_id = azurerm_postgresql_flexible_server.core.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "orders" {
  name      = "orders"
  server_id = azurerm_postgresql_flexible_server.core.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

###############################################
# Service Bus - core
###############################################
resource "azurerm_servicebus_namespace" "core" {
  name                = module.conventions.names.service_bus
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  sku  = "Standard"
  tags = module.conventions.tags
}

resource "azurerm_servicebus_queue" "orders" {
  name         = "orders"
  namespace_id = azurerm_servicebus_namespace.core.id
}

###############################################
# Private Endpoints
#
# All Private Endpoints are created in the same
# resource group as their parent PaaS resource
# and attach to the spoke_private_endpoints subnet.
###############################################
resource "azurerm_private_endpoint" "kv" {
  name                = module.conventions.names.pe_kv
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  subnet_id = azurerm_subnet.spoke_private_endpoints.id

  private_service_connection {
    name                           = "kv-pe"
    private_connection_resource_id = azurerm_key_vault.core.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }

  tags = module.conventions.tags
}

resource "azurerm_private_endpoint" "pg" {
  name                = module.conventions.names.pe_pg
  location            = var.location
  resource_group_name = azurerm_resource_group.data.name

  subnet_id = azurerm_subnet.spoke_private_endpoints.id

  private_service_connection {
    name                           = "pg-pe"
    private_connection_resource_id = azurerm_postgresql_flexible_server.core.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pg-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.pg.id]
  }

  tags = module.conventions.tags
}

###############################################
# Private DNS zones and links
###############################################
resource "azurerm_private_dns_zone" "kv" {
  name                = module.conventions.dns_zones.kv
  resource_group_name = azurerm_resource_group.core.name

  tags = module.conventions.tags
}

resource "azurerm_private_dns_zone" "pg" {
  name                = module.conventions.dns_zones.pg
  resource_group_name = azurerm_resource_group.core.name

  tags = module.conventions.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_hub" {
  name                  = "kv-hub-link"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_spoke" {
  name                  = "kv-spoke-link"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg_hub" {
  name                  = "pg-hub-link"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.pg.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg_spoke" {
  name                  = "pg-spoke-link"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.pg.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}
