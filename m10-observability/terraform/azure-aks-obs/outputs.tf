# Outputs for the M10 observability node pool.

output "node_pool" {
  description = "The pool the event store runs on (pods select it with the meridian/pool=obs label)."
  value       = azurerm_kubernetes_cluster_node_pool.obs.name
}

output "node_resource_group" {
  description = "Where AKS keeps the pool's scale set and the event store's load balancer IP."
  value       = data.azurerm_kubernetes_cluster.lab.node_resource_group
}
