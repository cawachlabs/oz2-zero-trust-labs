# =============================================================================
# Meridian Logistics — M07 Linux Tunneler Fleet Substrate
#
# Layers on top of M03/M04 (reuses rg-meridian-ziti-lab-01 + vnet-meridian-ziti-lab-eus-01):
#   snet-tun-eus-01  10.10.4.0/24   the reserved tunneler block
#   nsg-tun-eus-01   inbound SSH only — the tunneler itself needs NO inbound (it dials out)
#   vm-tun-lab-eus-01..03  Ubuntu 24.04, B1ms, static 10.10.4.10/.11/.12
# Field-built 2026-09-26 against controllers v2.0.3 + ziti-edge-tunnel 1.18.7 (apply ~1.5 min per phase;
# cloud-init VMs online ~1 min after the apply returns).
#
# Two-phase on purpose (Lab S02):
#   tofu apply                       # fleet_count = 1 -> VM #1 only, which you build BY HAND
#   ...mint tokens\linux-fleet-02.jwt / -03.jwt...
#   tofu apply -var fleet_count=3    # VMs #2-#3 boot with their token in cloud-init and enroll themselves
#
# IaC provisions the substrate only. The identities, tokens and policies are yours (the ziti CLI).
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

# Reference the existing M03 resource group and East US VNet — M07 destroys neither.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "eus" {
  name                = "vnet-meridian-ziti-lab-eus-01"
  resource_group_name = data.azurerm_resource_group.lab.name
}

locals {
  common_tags = {
    project      = "ztaoz20"
    module       = "m07"
    role         = "linux-fleet"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }

  # "01", "02", "03" — keyed, so raising or lowering fleet_count never renumbers a VM.
  fleet = {
    for i in range(var.fleet_count) : format("%02d", i + 1) => {
      identity   = "linux-fleet-${format("%02d", i + 1)}"
      private_ip = "10.10.4.${10 + i}"
      token_path = "${var.tokens_dir}/linux-fleet-${format("%02d", i + 1)}.jwt"
      # VM #1 is the hands-on endpoint: no cloud-init, you do every step yourself.
      auto_enroll = i > 0
    }
  }

  auto = { for k, v in local.fleet : k => v if v.auto_enroll }
}

# Tokens are only needed on the apply that CREATES a VM (custom_data is ignored afterwards,
# see the VM lifecycle block). A missing token warns instead of failing, so deleting the
# consumed tokens later never blocks a plan.
check "fleet_tokens_present" {
  assert {
    condition = alltrue([
      for k, v in local.auto : fileexists(v.token_path) && length(trimspace(file(v.token_path))) > 0
    ])
    error_message = "A token file is missing or empty in ${var.tokens_dir} (expected linux-fleet-NN.jwt for every VM after #1). Already enrolled? Ignore this: tokens are only read when a VM is created. About to create that VM? Mint the token first (Lab S02 Step 5) - a VM created without one boots but never enrolls."
  }
}

# =============================================================================
# Network: tunneler subnet + NSG (SSH only)
# =============================================================================

resource "azurerm_subnet" "tun_eus" {
  name                 = "snet-tun-eus-01"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = data.azurerm_virtual_network.eus.name
  address_prefixes     = ["10.10.4.0/24"]
}

resource "azurerm_network_security_group" "tun_eus" {
  name                = "nsg-tun-eus-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.common_tags

  # The only inbound rule. The tunneler dials OUT to the controllers (:1280) and the
  # public routers' edge port (:3022) — Azure's default outbound allow covers both.
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

resource "azurerm_subnet_network_security_group_association" "tun_eus" {
  subnet_id                 = azurerm_subnet.tun_eus.id
  network_security_group_id = azurerm_network_security_group.tun_eus.id
}

# =============================================================================
# The fleet: one public IP + NIC + VM per endpoint
# =============================================================================

resource "azurerm_public_ip" "fleet" {
  for_each            = local.fleet
  name                = "pip-tun-eus-${each.key}"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "fleet-${each.key}-${var.dns_prefix}"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "fleet" {
  for_each            = local.fleet
  name                = "nic-tun-eus-${each.key}"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.tun_eus.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = azurerm_public_ip.fleet[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "fleet" {
  for_each            = local.fleet
  name                = "vm-tun-lab-eus-${each.key}"
  computer_name       = "fleet-${each.key}"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = merge(local.common_tags, { identity = each.value.identity })

  network_interface_ids = [azurerm_network_interface.fleet[each.key].id]

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

  # VMs #2+ boot with cloud-init: the same install + seed + enable you did by hand on #1.
  # The one-time token rides in user-data (base64) — single-use, consumed on first boot.
  custom_data = !each.value.auto_enroll ? null : base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    identity_name = each.value.identity
    apt_suite     = var.openziti_apt_suite
    jwt_b64 = base64encode(
      fileexists(each.value.token_path) ? trimspace(file(each.value.token_path)) : ""
    )
  }))

  lifecycle {
    # The token is consumed at first boot. Without this, deleting or re-minting a token
    # file would make tofu REPLACE an enrolled VM on the next apply.
    ignore_changes = [custom_data]
  }
}
