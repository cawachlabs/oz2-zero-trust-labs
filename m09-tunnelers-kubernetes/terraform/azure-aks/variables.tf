# Variables for the M09 AKS cluster (East US).
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "subscription_id" {
  description = "Azure Subscription ID (same as M04/M06/M07)."
  type        = string
}

variable "resource_group_name" {
  description = "The shared lab resource group from M03."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag on every resource."
  type        = string
}

variable "dns_prefix" {
  description = "Short unique handle (same as M03/M04). The cluster's API server name becomes aks-<dns_prefix>-<hash>."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}[a-z0-9]$", var.dns_prefix))
    error_message = "dns_prefix must be lowercase letters/numbers/hyphens, start with a letter, end with a letter or number."
  }
}

variable "vm_size" {
  description = "Size of the one system node. An AKS system pool needs at least 2 vCPU / 4 GB; Standard_B2s is the smallest that fits."
  type        = string
  default     = "Standard_B2s"
}

variable "assign_subnet_role" {
  description = "Give the cluster's identity Network Contributor on snet-aks-eus-01. Needs Owner or User Access Administrator; set false if you have neither."
  type        = bool
  default     = true
}
