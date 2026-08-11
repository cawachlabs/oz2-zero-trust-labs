# The controllers' DNS names — used for SSH, bootstrap answers, and cluster add.
# Real DNS, resolvable from anywhere: no /etc/hosts editing on any machine.
output "controller_fqdns" {
  description = "Public FQDN per controller (the advertise addresses)."
  value = {
    for k, r in azurerm_public_ip.ctrl : local.regions[k].ctrl => r.fqdn
  }
}

output "controller_public_ips" {
  description = "Public IP per controller (ctrl1, ctrl2, ctrl3)."
  value = {
    for k, r in azurerm_public_ip.ctrl : local.regions[k].ctrl => r.ip_address
  }
}

output "controller_private_ips" {
  description = "Static private IP per controller — fixed by course convention (.10 in each subnet); survives restart/deallocate."
  value = {
    for k, r in local.regions : r.ctrl => r.private_ip
  }
}

output "reminder" {
  value = "tofu owns the whole lab — `tofu destroy` removes everything; re-`apply` recreates it."
}
