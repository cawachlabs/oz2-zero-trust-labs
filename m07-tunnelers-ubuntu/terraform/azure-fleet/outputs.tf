# Outputs for the M07 Linux tunneler fleet.

output "fleet_fqdns" {
  description = "Public FQDN per fleet VM (SSH only — the tunneler needs no inbound)."
  value       = { for k, v in local.fleet : v.identity => azurerm_public_ip.fleet[k].fqdn }
}

output "fleet_private_ips" {
  description = "Static private IP per fleet VM inside snet-tun-eus-01."
  value       = { for k, v in local.fleet : v.identity => azurerm_network_interface.fleet[k].private_ip_address }
}

output "ssh_commands" {
  description = "Convenience SSH command per fleet VM."
  value       = { for k, v in local.fleet : v.identity => "ssh ${var.admin_username}@${azurerm_public_ip.fleet[k].fqdn}" }
}

output "enrollment" {
  description = "How each VM enrolls: by hand (#1) or cloud-init at first boot (#2+)."
  value       = { for k, v in local.fleet : v.identity => v.auto_enroll ? "cloud-init (token from ${v.token_path})" : "by hand (Lab S02 Steps 2-4)" }
}
