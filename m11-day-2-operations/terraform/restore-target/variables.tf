variable "subscription_id" {
  description = "Azure subscription that hosts the lab."
  type        = string
}

variable "owner" {
  description = "Your name, for the owner tag."
  type        = string
}

variable "dns_prefix" {
  description = "Same prefix as the other modules; the rig's FQDN is restore-<dns_prefix>.<region>.cloudapp.azure.com."
  type        = string
}

variable "ssh_public_key" {
  description = "Your SSH public key (the same one the other lab VMs use)."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Who may SSH to the rig. Your public IP /32 is best."
  type        = string
  default     = "0.0.0.0/0"
}

variable "location" {
  description = "Azure region for the rig."
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "VM size — a single lab controller needs little."
  type        = string
  default     = "Standard_B1ms"
}

variable "admin_username" {
  description = "Admin user on the VM."
  type        = string
  default     = "azureuser"
}
