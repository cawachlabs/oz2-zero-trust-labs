output "ctrl4_fqdn" {
  description = "ctrl4's public address — the controller's advertised address and your SSH jump host."
  value       = azurerm_public_ip.ctrl4.fqdn
}

output "private_ips" {
  description = "The four private VMs — reach them with ssh -J azureuser@<ctrl4_fqdn> azureuser@<ip>."
  value       = { for k, v in local.vms : k => v.ip if !v.public }
}
