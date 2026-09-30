# =============================================================================
# Meridian Logistics — M09 AKS Cluster Substrate
#
# Layers on top of M03/M04 (reuses rg-meridian-ziti-lab-01 + vnet-meridian-ziti-lab-eus-01):
#   snet-aks-eus-01          10.10.5.0/24   the reserved AKS block (nodes only — pods use the overlay)
#   aks-meridian-lab-eus-01  ONE node, Azure CNI overlay, fixed service range 10.0.0.0/16 (kube-dns = 10.0.0.10)
#
# One node on purpose: the node proxy's identity claim is ReadWriteOnce (Lab S03 Step 6), which one node
# can serve and two cannot.
#
# IaC provisions the substrate only. Identities, tokens, charts and policies are yours (ziti, helm, kubectl).
# AKS costs real money while it exists — `tofu destroy` between sessions (README).
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

# Reference the existing M03 resource group and East US VNet — M09 destroys neither.
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
    module       = "m09"
    role         = "aks"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

# =============================================================================
# Network: the AKS node subnet
# =============================================================================

resource "azurerm_subnet" "aks_eus" {
  name                 = "snet-aks-eus-01"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = data.azurerm_virtual_network.eus.name
  address_prefixes     = ["10.10.5.0/24"]
}

# =============================================================================
# The cluster
# =============================================================================

resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-meridian-lab-eus-01"
  location            = data.azurerm_virtual_network.eus.location
  resource_group_name = data.azurerm_resource_group.lab.name
  dns_prefix          = "aks-${var.dns_prefix}"
  sku_tier            = "Free"
  tags                = local.common_tags

  default_node_pool {
    name                        = "system"
    node_count                  = 1
    vm_size                     = var.vm_size
    os_disk_size_gb             = 32
    vnet_subnet_id              = azurerm_subnet.aks_eus.id
    temporary_name_for_rotation = "systemtmp"
    tags                        = local.common_tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure CNI overlay: nodes take addresses from snet-aks-eus-01, pods from a private overlay range.
  # The service range is written out (not left to the default) so the kube-dns address is known in
  # advance: 10.0.0.10 is the second nameserver in kubernetes\manifests\dispatch-sidecar.yaml.
  # None of these ranges overlap Meridian's (10.10-10.50/16, 172.16.x) — nothing is peered anyway.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }
}

# A cluster in your own subnet needs Network Contributor on it (AKS docs, "bring your own subnet").
# `az aks create` adds this for you; OpenTofu has to say it. Assigning a role needs Owner or
# User Access Administrator on the lab resource group — without that, set
# assign_subnet_role = false (README, Troubleshooting).
resource "azurerm_role_assignment" "aks_subnet" {
  count                = var.assign_subnet_role ? 1 : 0
  scope                = azurerm_subnet.aks_eus.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.lab.identity[0].principal_id
}
