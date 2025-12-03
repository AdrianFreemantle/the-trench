resource "azurerm_log_analytics_workspace" "core" {
  name                = module.conventions.names.log_analytics
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  sku                 = "PerGB2018"
  retention_in_days   = 2
  tags                = module.conventions.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-to-log-analytics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.core.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
