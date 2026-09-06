# Outputs for the M04 public edge routers.

output "edge_router_fqdns" {
  description = "Public FQDNs for the edge routers — use for edge & link listeners."
  value = {
    "er-pub-01" = azurerm_public_ip.er_eus.fqdn
    "er-pub-02" = azurerm_public_ip.er_cin.fqdn
  }
}

output "edge_router_public_ips" {
  description = "Public IP addresses for the edge routers."
  value = {
    "er-pub-01" = azurerm_public_ip.er_eus.ip_address
    "er-pub-02" = azurerm_public_ip.er_cin.ip_address
  }
}

output "edge_router_private_ips" {
  description = "Static private IPs inside each region's VNet."
  value = {
    "er-pub-01" = azurerm_network_interface.er_eus.private_ip_address
    "er-pub-02" = azurerm_network_interface.er_cin.private_ip_address
  }
}

output "ssh_commands" {
  description = "Convenience commands to SSH into each edge router."
  value = {
    "er-pub-01" = "ssh ${var.admin_username}@${azurerm_public_ip.er_eus.fqdn}"
    "er-pub-02" = "ssh ${var.admin_username}@${azurerm_public_ip.er_cin.fqdn}"
  }
}
