# =============================================================================
# Meridian Logistics — M13 capstone: the APAC region (Azure Southeast Asia)
#
# Five VMs in a new VNet (vnet-meridian-ziti-lab-sea-01, 10.40.0.0/16 — the M03 reservation):
#   vm-ctrl4-lab-sea-01   10.40.1.10   the non-voting controller — the ONLY public address (1280 for the
#                                      cluster and clients, 22 from your IP); also the SSH jump host
#   vm-er-sea-01 / -02    10.40.2.10/.11  two PRIVATE routers — no public IP; they dial out to the
#                                      controllers and to the public routers' link listeners
#   vm-wms-ap-01          10.40.3.10   the second WMS host (nginx + the tunneler hosting meridian-wms)
#   vm-tun-lab-sea-01     10.40.4.10   the Singapore depot (linux-fleet-ap-01) — a client
# The depot and the WMS host enroll at first boot from tokens you put in ./tokens (M07's cloud-init way).
# The controller and the routers are installed by hand (Lab Steps 3–4) — the M03 / M04 steps again.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  location = "southeastasia"
  tags = {
    project      = "ztaoz20"
    module       = "m13"
    region       = "sea"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
  subnets = {
    ctrl = "10.40.1.0/24"
    er   = "10.40.2.0/24"
    svc  = "10.40.3.0/24"
    tun  = "10.40.4.0/24"
  }
  # name => subnet, static IP, size
  vms = {
    "vm-ctrl4-lab-sea-01" = { subnet = "ctrl", ip = "10.40.1.10", size = "Standard_B2s", public = true }
    "vm-er-sea-01"        = { subnet = "er", ip = "10.40.2.10", size = "Standard_B1ms", public = false }
    "vm-er-sea-02"        = { subnet = "er", ip = "10.40.2.11", size = "Standard_B1ms", public = false }
    "vm-wms-ap-01"        = { subnet = "svc", ip = "10.40.3.10", size = "Standard_B1ms", public = false }
    "vm-tun-lab-sea-01"   = { subnet = "tun", ip = "10.40.4.10", size = "Standard_B1ms", public = false }
  }
  cloud_init = {
    "vm-wms-ap-01"      = templatefile("${path.module}/wms-host.yaml.tftpl", { identity_name = "ziti-host-wms-ap-01", apt_suite = var.openziti_apt_suite, jwt_b64 = fileexists("${var.tokens_dir}/ziti-host-wms-ap-01.jwt") ? base64encode(trimspace(file("${var.tokens_dir}/ziti-host-wms-ap-01.jwt"))) : "" })
    "vm-tun-lab-sea-01" = templatefile("${path.module}/depot.yaml.tftpl", { identity_name = "linux-fleet-ap-01", apt_suite = var.openziti_apt_suite, jwt_b64 = fileexists("${var.tokens_dir}/linux-fleet-ap-01.jwt") ? base64encode(trimspace(file("${var.tokens_dir}/linux-fleet-ap-01.jwt"))) : "" })
  }
}

check "tokens_present" {
  assert {
    condition     = fileexists("${var.tokens_dir}/linux-fleet-ap-01.jwt") && fileexists("${var.tokens_dir}/ziti-host-wms-ap-01.jwt")
    error_message = "Put linux-fleet-ap-01.jwt and ziti-host-wms-ap-01.jwt in ${var.tokens_dir} first (Lab Step 1) — a VM created without its token boots but never enrolls."
  }
}

data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "sea" {
  name                = "vnet-meridian-ziti-lab-sea-01"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "sea" {
  for_each                        = local.subnets
  name                            = "snet-${each.key}-sea-01"
  resource_group_name             = data.azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.sea.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = true # the private VMs still reach the controllers, the routers and the package repo
}

# One NSG for the region: 1280 (controller) from anywhere — like M03; SSH from your IP to ctrl4 only;
# SSH and the edge port (3022) inside the VNet, so ctrl4 is the jump host and the depot / WMS host reach the routers.
resource "azurerm_network_security_group" "sea" {
  name                = "nsg-meridian-sea-01"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "AllowZitiCtrl"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1280"
    source_address_prefix      = "*"
    destination_address_prefix = "10.40.1.10"
  }
  security_rule {
    name                       = "AllowSSHToCtrl4"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "10.40.1.10"
  }
  security_rule {
    name                       = "AllowInsideVnet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3022"]
    source_address_prefix      = "10.40.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sea" {
  for_each                  = azurerm_subnet.sea
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.sea.id
}

resource "azurerm_public_ip" "ctrl4" {
  name                = "pip-ctrl4-sea-01"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "ctrl4-${var.dns_prefix}"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  for_each            = local.vms
  name                = replace(each.key, "vm-", "nic-")
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.sea[each.value.subnet].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    public_ip_address_id          = each.value.public ? azurerm_public_ip.ctrl4.id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each              = local.vms
  name                  = each.key
  computer_name         = replace(replace(each.key, "vm-", ""), "-lab-sea-01", "")
  location              = local.location
  resource_group_name   = data.azurerm_resource_group.lab.name
  size                  = each.value.size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm[each.key].id]
  custom_data           = contains(keys(local.cloud_init), each.key) ? base64encode(local.cloud_init[each.key]) : null
  tags                  = local.tags
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
