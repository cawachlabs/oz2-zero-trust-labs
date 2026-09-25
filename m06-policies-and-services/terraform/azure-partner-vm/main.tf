# Meridian Logistics — M06 Partner Endpoint (Azure Windows 11 VM)
#
# Deploys a dedicated Windows 11 workstation in East US for the external partner:
#   - Subnet: snet-partner-eus-01 (10.10.3.0/24) on vnet-meridian-ziti-lab-eus-01
#   - Public IP: partner-01-<dns_prefix>.eastus.cloudapp.azure.com
#   - RDP Port 3389 open to allowed_rdp_cidr
#   - Manual ZDEW installation via browser/RDP by students
#
# Lifecycle:
#   cd m06-policies-and-services/terraform/azure-partner-vm
#   tofu init && tofu plan && tofu apply

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

# Reference the existing M03/M04 resource group
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

locals {
  common_tags = {
    project      = "ztaoz20"
    module       = "m06"
    role         = "partner-workstation"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

# Reference existing East US VNet from M03/M04
data "azurerm_virtual_network" "eus" {
  name                = "vnet-meridian-ziti-lab-eus-01"
  resource_group_name = data.azurerm_resource_group.lab.name
}

# Dedicated subnet for partner workstation in East US VNet
resource "azurerm_subnet" "partner_eus" {
  name                 = "snet-partner-eus-01"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = data.azurerm_virtual_network.eus.name
  address_prefixes     = ["10.10.3.0/24"]
}

# Public IP with stable FQDN for RDP access
resource "azurerm_public_ip" "partner_pip" {
  name                = "pip-partner-01-eus"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_virtual_network.eus.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "partner-01-${var.dns_prefix}"
  tags                = local.common_tags
}

# NSG allowing RDP from allowed_rdp_cidr
resource "azurerm_network_security_group" "partner_nsg" {
  name                = "nsg-partner-01-eus"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_virtual_network.eus.location
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_cidr
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "partner_nic" {
  name                = "nic-partner-01-eus"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_virtual_network.eus.location
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig-partner-01"
    subnet_id                     = azurerm_subnet.partner_eus.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.partner_pip.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "partner_assoc" {
  network_interface_id      = azurerm_network_interface.partner_nic.id
  network_security_group_id = azurerm_network_security_group.partner_nsg.id
}

# Windows 11 Virtual Machine
resource "azurerm_windows_virtual_machine" "partner_vm" {
  name                = "vm-partner-01-eus"
  computer_name       = "partner-01"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_virtual_network.eus.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.partner_nic.id
  ]
  tags = local.common_tags

  secure_boot_enabled = true
  vtpm_enabled        = true

  os_disk {
    name                 = "osdisk-partner-01-eus"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}

