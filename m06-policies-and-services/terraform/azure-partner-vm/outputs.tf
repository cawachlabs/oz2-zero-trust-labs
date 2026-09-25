# Outputs for the M06 Partner Windows 11 VM

output "partner_vm_fqdn" {
  description = "Public FQDN of the partner Windows VM."
  value       = azurerm_public_ip.partner_pip.fqdn
}

output "partner_vm_public_ip" {
  description = "Public IP address of the partner Windows VM."
  value       = azurerm_public_ip.partner_pip.ip_address
}

output "partner_vm_private_ip" {
  description = "Private IP address in snet-partner-eus-01."
  value       = azurerm_network_interface.partner_nic.private_ip_address
}

output "admin_username" {
  description = "Admin username for RDP login."
  value       = var.admin_username
}

output "rdp_connection_string" {
  description = "Convenient RDP command to connect from Windows workstation."
  value       = "mstsc /v:${azurerm_public_ip.partner_pip.fqdn}"
}
