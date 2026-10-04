output "restore_fqdn" {
  description = "The rig's public FQDN — the address you give the controller install."
  value       = azurerm_public_ip.restore.fqdn
}

output "ssh_command" {
  description = "Convenience SSH command."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.restore.fqdn}"
}
