# =============================================================================
# Meridian Logistics — M10 observability node pool
#
# Adds ONE node pool to M09's AKS cluster (aks-meridian-lab-eus-01) for the event store:
# Elasticsearch, Kibana and Grafana need more memory than the cluster's one Standard_B2s system node has.
# The pool joins the same subnet (snet-aks-eus-01). M09's module stays untouched; this module only
# reads the cluster and the subnet.
#
# IaC provisions the substrate only. Everything OpenZiti and Elastic is done by hand (Lab S03).
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

data "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-meridian-lab-eus-01"
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks-eus-01"
  virtual_network_name = "vnet-meridian-ziti-lab-eus-01"
  resource_group_name  = var.resource_group_name
}

locals {
  common_tags = {
    project      = "ztaoz20"
    module       = "m10"
    role         = "observability"
    env          = "lab"
    owner        = var.owner
    autoteardown = "true"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "obs" {
  name                  = "obs"
  kubernetes_cluster_id = data.azurerm_kubernetes_cluster.lab.id
  vm_size               = var.vm_size
  node_count            = 1
  os_disk_size_gb       = 64
  vnet_subnet_id        = data.azurerm_subnet.aks.id
  mode                  = "User"
  node_labels           = { "meridian/pool" = "obs" }
  tags                  = local.common_tags

  upgrade_settings {
    max_surge = "10%"
  }
}
