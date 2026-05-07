# ===================================================================
# Azure Kubernetes Service (AKS) Module - Outputs
# ===================================================================
# Exposes important information about the created AKS cluster
# ===================================================================

output "aks_id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_kube_config" {
  description = "Kubernetes configuration for accessing the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_node_resource_group" {
  description = "The auto-generated resource group which contains the resources for this managed Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "aks_identity_principal_id" {
  description = "The Principal ID of the system assigned managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "aks_kubelet_identity_object_id" {
  description = "The Object ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "system_node_pool_id" {
  description = "The ID of the system node pool"
  value       = azurerm_kubernetes_cluster.main.default_node_pool[0].name
}

output "worker_node_pool_id" {
  description = "The ID of the worker node pool"
  value       = azurerm_kubernetes_cluster_node_pool.worker.id
}

output "worker_node_pool_name" {
  description = "The name of the worker node pool"
  value       = azurerm_kubernetes_cluster_node_pool.worker.name
}
