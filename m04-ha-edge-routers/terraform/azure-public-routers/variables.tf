# Variables for the M04 public edge routers (East US + Central India).
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "subscription_id" {
  description = "Azure Subscription ID."
  type        = string
}

variable "resource_group_name" {
  description = "The shared lab resource group from M03."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "ssh_public_key" {
  description = "Your SSH public key (contents of ~/.ssh/id_ed25519.pub or similar)."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Source allowed to SSH to the edge routers. Default 0.0.0.0/0 (open, key-only auth)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag on every resource."
  type        = string
}

variable "dns_prefix" {
  description = "Short unique handle for public DNS names: er-pub-01-<dns_prefix>.eastus.cloudapp.azure.com etc."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}[a-z0-9]$", var.dns_prefix))
    error_message = "dns_prefix must be lowercase letters/numbers/hyphens, start with a letter, end with a letter or number."
  }
}

variable "admin_username" {
  description = "Admin user on the VMs."
  type        = string
  default     = "azureuser"
}
