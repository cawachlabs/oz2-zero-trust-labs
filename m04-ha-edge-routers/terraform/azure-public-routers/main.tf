# =============================================================================
# Meridian Logistics — M04 Public Edge Routers Substrate
#
# Layers on top of M03 HA controllers:
#   er-pub-01  -> East US       (reuses vnet-meridian-ziti-lab-eus-01, new snet-er-eus-01 10.10.2.0/24)
#   er-pub-02  -> Central India (new vnet-meridian-ziti-lab-cin-01 10.50.0.0/16, snet-er-cin-01 10.50.2.0/24)
#
# Lifecycle:
#   cd m04-ha-edge-routers/terraform/azure-public-routers
#   tofu init && tofu plan && tofu apply
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
  # Pinned to Pre-Sales subscription
  subscription_id = var.subscription_id
}

# Reference the existing M03 resource group — M04 does not destroy it.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

locals {
  common_tags = {
    project      = "ztaoz20"
    module       = "m04"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

# =============================================================================
# Router 1: er-pub-01 (East US)
# Reuses existing East US VNet from M03, adds edge router subnet
# =============================================================================

data "azurerm_virtual_network" "eus" {
  name                = "vnet-meridian-ziti-lab-eus-01"
  resource_group_name = data.azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "er_eus" {
  name                 = "snet-er-eus-01"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = data.azurerm_virtual_network.eus.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_network_security_group" "er_eus" {
  name                = "nsg-er-eus-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
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

  security_rule {
    name                       = "AllowZitiEdge"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowZitiLink"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6004"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "er_eus" {
  subnet_id                 = azurerm_subnet.er_eus.id
  network_security_group_id = azurerm_network_security_group.er_eus.id
}

resource "azurerm_public_ip" "er_eus" {
  name                = "pip-er-eus-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "er-pub-01-${var.dns_prefix}"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "er_eus" {
  name                = "nic-er-eus-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.er_eus.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.2.10"
    public_ip_address_id          = azurerm_public_ip.er_eus.id
  }
}

resource "azurerm_linux_virtual_machine" "er_eus" {
  name                = "vm-er-eus-01"
  computer_name       = "er-pub-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.er_eus.id]

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

# =============================================================================
# Router 2: er-pub-02 (Central India)
# Creates new Central India VNet and edge router subnet
# =============================================================================

resource "azurerm_virtual_network" "cin" {
  name                = "vnet-meridian-ziti-lab-cin-01"
  location            = "centralindia"
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.50.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "er_cin" {
  name                 = "snet-er-cin-01"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.cin.name
  address_prefixes     = ["10.50.2.0/24"]
}

resource "azurerm_network_security_group" "er_cin" {
  name                = "nsg-er-cin-01"
  location            = "centralindia"
  resource_group_name = data.azurerm_resource_group.lab.name
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

  security_rule {
    name                       = "AllowZitiEdge"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3022"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowZitiLink"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6004"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "er_cin" {
  subnet_id                 = azurerm_subnet.er_cin.id
  network_security_group_id = azurerm_network_security_group.er_cin.id
}

resource "azurerm_public_ip" "er_cin" {
  name                = "pip-er-cin-01"
  location            = "centralindia"
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "er-pub-02-${var.dns_prefix}"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "er_cin" {
  name                = "nic-er-cin-01"
  location            = "centralindia"
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.er_cin.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.50.2.10"
    public_ip_address_id          = azurerm_public_ip.er_cin.id
  }
}

resource "azurerm_linux_virtual_machine" "er_cin" {
  name                = "vm-er-cin-01"
  computer_name       = "er-pub-02"
  location            = "centralindia"
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.er_cin.id]

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
