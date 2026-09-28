# Variables for the M07 Linux tunneler fleet (East US).
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "subscription_id" {
  description = "Azure Subscription ID (same as M04/M06)."
  type        = string
}

variable "resource_group_name" {
  description = "The shared lab resource group from M03."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "ssh_public_key" {
  description = "Your SSH public key (same as M03/M04)."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Source allowed to SSH to the fleet VMs. Key-only auth; tighten to \"<your-ip>/32\" if your IP is stable."
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag on every resource."
  type        = string
}

variable "dns_prefix" {
  description = "Short unique handle for public DNS names: fleet-01-<dns_prefix>.eastus.cloudapp.azure.com (same as M03/M04)."
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

variable "fleet_count" {
  description = "How many fleet VMs exist. 1 = VM #1 only (built by hand); 3 = the full fleet (#2-#3 via cloud-init)."
  type        = number
  default     = 1
  validation {
    condition     = var.fleet_count >= 1 && var.fleet_count <= 3 && floor(var.fleet_count) == var.fleet_count
    error_message = "fleet_count must be 1, 2 or 3 (snet-tun-eus-01 plans 10.10.4.10-.12)."
  }
}

variable "vm_size" {
  description = "VM size for each fleet endpoint (1 vCPU / 2 GB is plenty for a tunneler)."
  type        = string
  default     = "Standard_B1ms"
}

variable "tokens_dir" {
  description = "Folder holding linux-fleet-02.jwt / linux-fleet-03.jwt (the one-time enrollment tokens). Relative to this module."
  type        = string
  default     = "./tokens"
}

variable "openziti_apt_suite" {
  description = "Suite of the OpenZiti APT repo that carries ziti-edge-tunnel. Only jammy publishes it (no noble suite exists)."
  type        = string
  default     = "jammy"
}
