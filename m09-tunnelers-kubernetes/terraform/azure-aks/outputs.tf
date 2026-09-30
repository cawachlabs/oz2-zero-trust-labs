# Outputs for the M09 AKS cluster.

output "cluster_name" {
  description = "The AKS cluster — also the kubectl context name in the kubeconfig below."
  value       = azurerm_kubernetes_cluster.lab.name
}

output "kube_dns_ip" {
  description = "The kube-dns service address — the second nameserver in dispatch-sidecar.yaml."
  value       = azurerm_kubernetes_cluster.lab.network_profile[0].dns_service_ip
}

output "node_resource_group" {
  description = "The resource group AKS creates for the node's VM scale set, load balancer and disks (deleted with the cluster)."
  value       = azurerm_kubernetes_cluster.lab.node_resource_group
}

output "kubeconfig" {
  description = "kubeconfig for the cluster. Write it with: tofu output -raw kubeconfig | Out-File -Encoding ascii $HOME\\.kube\\meridian-aks"
  value       = azurerm_kubernetes_cluster.lab.kube_config_raw
  sensitive   = true
}
