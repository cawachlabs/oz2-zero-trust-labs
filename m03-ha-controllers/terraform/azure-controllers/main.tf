# =============================================================================
# Meridian Logistics — M03 controller substrate (THE WHOLE LAB)
#
# tofu owns everything: the resource group + all three regions —
#   East US     -> ctrl1   (10.10.0.0/16)
#   Central US  -> ctrl2   (10.20.0.0/16)
#   West Europe -> ctrl3   (10.30.0.0/16)
# Full lifecycle: `tofu apply` brings the lab up, `tofu destroy` removes it
# completely — recreate as often as you like.
#
# The lab's Portal demo uses a separate THROWAWAY demo stack (rg-…-demo-…),
# deleted right after — it never collides with these resources.
#
# Naming/CIDRs/tags follow the course's Meridian lab conventions (taught in the
# M03 lessons): vnet-/snet-/nsg-/pip-/nic-/vm- prefixes, 10.<region>0.0/16 blocks.
# Commands: tofu init && tofu plan && tofu apply   (terraform works identically)
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
  # Auth: run `az login` first (simplest path for a lab workstation).
}

# The lab resource group — tofu-owned; destroying it removes the entire lab.
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = "eastus"
  tags     = local.common_tags
}

locals {
  # All three regions — the complete control-plane substrate.
  # private_ip: STATIC (course standard) — instances start at .10 in their
  # subnet (Azure reserves .0–.3); restarts/deallocations never change it.
  regions = {
    eus = {
      location    = "eastus"
      ctrl        = "ctrl1"
      vnet_cidr   = "10.10.0.0/16"
      subnet_cidr = "10.10.1.0/24"
      private_ip  = "10.10.1.10"
    }
    cus = {
      location    = "centralus"
      ctrl        = "ctrl2"
      vnet_cidr   = "10.20.0.0/16"
      subnet_cidr = "10.20.1.0/24"
      private_ip  = "10.20.1.10"
    }
    weu = {
      location    = "westeurope"
      ctrl        = "ctrl3"
      vnet_cidr   = "10.30.0.0/16"
      subnet_cidr = "10.30.1.0/24"
      private_ip  = "10.30.1.10"
    }
  }

  common_tags = {
    project      = "ztaoz20"
    module       = "m03"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

# ---------------------------------------------------------------- networking ---
resource "azurerm_virtual_network" "ctrl" {
  for_each            = local.regions
  name                = "vnet-meridian-ziti-lab-${each.key}-01"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [each.value.vnet_cidr]
  tags                = local.common_tags
}

resource "azurerm_subnet" "ctrl" {
  for_each             = local.regions
  name                 = "snet-ctrl-${each.key}-01"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.ctrl[each.key].name
  address_prefixes     = [each.value.subnet_cidr]
}

resource "azurerm_network_security_group" "ctrl" {
  for_each            = local.regions
  name                = "nsg-ctrl-${each.key}-01"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  # Open to the world BY DESIGN: 1280 is the controller's edge/client API —
  # every connection is mTLS-authenticated by OpenZiti itself, and future
  # routers/tunnelers (M04+) must reach it from anywhere. Zero trust means
  # the authentication lives in the protocol, not the firewall.
  security_rule {
    name                       = "AllowZitiCtrl"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1280"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "ctrl" {
  for_each                  = local.regions
  subnet_id                 = azurerm_subnet.ctrl[each.key].id
  network_security_group_id = azurerm_network_security_group.ctrl[each.key].id
}

resource "azurerm_public_ip" "ctrl" {
  for_each            = local.regions
  name                = "pip-${each.value.ctrl}-${each.key}-01"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  # Free Azure DNS name: ctrl1-<dns_prefix>.eastus.cloudapp.azure.com — the
  # controllers' advertise addresses. Real DNS, resolvable from anywhere
  # (your workstation, future M04 routers) — no /etc/hosts editing, ever.
  domain_name_label   = "${each.value.ctrl}-${var.dns_prefix}"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "ctrl" {
  for_each            = local.regions
  name                = "nic-${each.value.ctrl}-${each.key}-01"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.ctrl[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = azurerm_public_ip.ctrl[each.key].id
  }
}

# ----------------------------------------------------------------------- VMs ---
resource "azurerm_linux_virtual_machine" "ctrl" {
  for_each            = local.regions
  name                = "vm-${each.value.ctrl}-lab-${each.key}-01"
  computer_name       = each.value.ctrl # OS hostname = controller id (identity-mapping rule)
  location            = each.value.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.ctrl[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu 24.04 LTS (Canonical) — URN Canonical:ubuntu-24_04-lts:server:latest.
  # If your subscription can't see it: az vm image list --publisher Canonical --all
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
