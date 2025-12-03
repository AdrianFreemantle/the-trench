resource "azurerm_public_ip" "jump_host" {
  name                = module.conventions.names.jump_host_pip
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = module.conventions.tags
}

resource "azurerm_network_security_group" "jump_host" {
  name                = module.conventions.names.jump_host_nsg
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  security_rule {
    name                       = "ssh-admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.jump_host_allowed_source_ip
    destination_address_prefix = "*"
  }

  tags = module.conventions.tags
}

resource "azurerm_network_interface" "jump_host" {
  name                = module.conventions.names.jump_host_nic
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.hub_shared_services.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump_host.id
  }

  tags = module.conventions.tags
}

resource "azurerm_network_interface_security_group_association" "jump_host" {
  network_interface_id      = azurerm_network_interface.jump_host.id
  network_security_group_id = azurerm_network_security_group.jump_host.id
}

resource "azurerm_linux_virtual_machine" "jump_host" {
  name                            = module.conventions.names.jump_host_vm
  resource_group_name             = azurerm_resource_group.core.name
  location                        = var.location
  size                            = "Standard_D1_v2"
  admin_username                  = var.jump_host_admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.jump_host.id,
  ]

  admin_ssh_key {
    username   = var.jump_host_admin_username
    public_key = var.jump_host_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
  #cloud-config
  package_update: true
  packages:
    - snapd
    - curl
    - git
  runcmd:
    - snap install kubectl --classic
    - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  EOT
  )

  tags = module.conventions.tags
}
