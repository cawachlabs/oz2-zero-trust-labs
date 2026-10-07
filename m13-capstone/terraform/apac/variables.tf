variable "subscription_id" {
  description = "Azure subscription that hosts the lab."
  type        = string
}

variable "resource_group_name" {
  description = "The course's single resource group (it holds every region)."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "owner" {
  description = "Your name, for the owner tag."
  type        = string
}

variable "dns_prefix" {
  description = "Same prefix as the other modules; ctrl4's FQDN is ctrl4-<dns_prefix>.southeastasia.cloudapp.azure.com."
  type        = string
}

variable "ssh_public_key" {
  description = "Your SSH public key (the same one the other lab VMs use)."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Who may SSH to ctrl4 (the jump host). Your public IP /32 is best."
  type        = string
  default     = "0.0.0.0/0"
}

variable "admin_username" {
  description = "Admin user on every VM."
  type        = string
  default     = "azureuser"
}

variable "tokens_dir" {
  description = "Folder holding linux-fleet-ap-01.jwt and ziti-host-wms-ap-01.jwt (Lab Step 1)."
  type        = string
  default     = "./tokens"
}

variable "openziti_apt_suite" {
  description = "The tunneler is published only under the jammy suite; the jammy build installs cleanly on 24.04 (M07)."
  type        = string
  default     = "jammy"
}
