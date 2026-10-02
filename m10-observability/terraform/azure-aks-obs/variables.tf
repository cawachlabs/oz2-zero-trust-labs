# Variables for the M10 observability node pool.
# Copy terraform.tfvars.example to terraform.tfvars and fill in your values.

variable "subscription_id" {
  description = "Azure Subscription ID (same as M04-M09)."
  type        = string
}

variable "resource_group_name" {
  description = "The shared lab resource group from M03."
  type        = string
  default     = "rg-meridian-ziti-lab-01"
}

variable "owner" {
  description = "Your name/handle — lands in the 'owner' tag."
  type        = string
}

variable "vm_size" {
  description = "Size of the one observability node. Elasticsearch + Kibana + Grafana fit in 4 vCPU / 16 GB."
  type        = string
  default     = "Standard_B4ms"
}
