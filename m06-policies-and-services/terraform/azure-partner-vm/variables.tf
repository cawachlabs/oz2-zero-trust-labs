# Variables for the M06 Partner Endpoint (Azure Windows VM).
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "subscription_id" {
  description = "Azure Subscription ID."
  type        = string
}

variable "resource_group_name" {
  description = "The shared lab resource group from M03/M04."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "allowed_rdp_cidr" {
  description = "Source IP/CIDR allowed to RDP to the partner Windows VM (e.g. your workstation public IP /32 or 0.0.0.0/0)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag on every resource."
  type        = string
}

variable "dns_prefix" {
  description = "Short unique handle for public DNS names: partner-01-<dns_prefix>.eastus.cloudapp.azure.com (same as M03/M04)."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}[a-z0-9]$", var.dns_prefix))
    error_message = "dns_prefix must be lowercase letters/numbers/hyphens, start with a letter, end with a letter or number."
  }
}

variable "admin_username" {
  description = "Admin username on the Windows VM."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for RDP access to the Windows VM (must satisfy Windows complexity: >=12 chars, upper, lower, digit, special)."
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "VM size for the Windows 11 client."
  type        = string
  default     = "Standard_B2ms"
}
