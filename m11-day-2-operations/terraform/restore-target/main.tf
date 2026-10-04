# =============================================================================
# Meridian Logistics — M11 restore rig (throwaway)
#
# ONE small Ubuntu VM in its OWN resource group, so `tofu destroy` can never touch the course estate.
# It proves the backup: a fresh controller rebuilds Meridian's model from the snapshot file.
# Only SSH is open (from allowed_ssh_cidr) — the proof runs on the rig itself, no controller port is exposed.
#
# IaC provisions the substrate only. Installing the controller and restoring is done by hand (Lab Steps 3-5).
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  common_tags = {
    project      = "ztaoz20"
    module       = "m11"
    role         = "restore-rig"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

resource "azurerm_resource_group" "restore" {
  name     = "rg-meridian-m11-restore-eus-01"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "restore" {
  name                = "vnet-meridian-restore-eus-01"
  location            = azurerm_resource_group.restore.location
  resource_group_name = azurerm_resource_group.restore.name
  address_space       = ["10.30.0.0/24"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "restore" {
  name                 = "snet-restore-eus-01"
  resource_group_name  = azurerm_resource_group.restore.name
  virtual_network_name = azurerm_virtual_network.restore.name
  address_prefixes     = ["10.30.0.0/26"]
}

resource "azurerm_network_security_group" "restore" {
  name                = "nsg-restore-eus-01"
  location            = azurerm_resource_group.restore.location
  resource_group_name = azurerm_resource_group.restore.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "restore" {
  subnet_id                 = azurerm_subnet.restore.id
  network_security_group_id = azurerm_network_security_group.restore.id
}

resource "azurerm_public_ip" "restore" {
  name                = "pip-restore-eus-01"
  location            = azurerm_resource_group.restore.location
  resource_group_name = azurerm_resource_group.restore.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "restore-${var.dns_prefix}"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "restore" {
  name                = "nic-restore-eus-01"
  location            = azurerm_resource_group.restore.location
  resource_group_name = azurerm_resource_group.restore.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.restore.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.restore.id
  }
}

resource "azurerm_linux_virtual_machine" "restore" {
  name                  = "vm-ctrl-restore-eus-01"
  computer_name         = "ctrl-restore"
  location              = azurerm_resource_group.restore.location
  resource_group_name   = azurerm_resource_group.restore.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.restore.id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
