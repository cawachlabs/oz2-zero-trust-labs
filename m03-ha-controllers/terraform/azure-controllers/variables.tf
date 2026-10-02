# Variables for the M03 lab substrate (all three regions).
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "resource_group_name" {
  description = "The lab resource group — tofu-owned; `tofu destroy` removes the whole lab."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "ssh_public_key" {
  description = "Your SSH public key (contents of ~/.ssh/id_ed25519.pub or similar)."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Source allowed to SSH to the controllers. Default 0.0.0.0/0 (open, key-only auth) — the sane lab default since most home connections have dynamic/CGNAT IPs. If you DO have a stable public IP, tighten to <ip>/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag on every resource."
  type        = string
}

variable "dns_prefix" {
  description = "Short unique handle for your controllers' public DNS names: ctrl1-<dns_prefix>.eastus.cloudapp.azure.com etc. Lowercase letters/numbers/hyphens; must be unique per Azure region, so make it yours (e.g. meridian-jdoe)."
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
