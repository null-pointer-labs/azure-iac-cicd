
# -------------------------------------------------------------------
# Azure Kubernetes Service (AKS)
# -------------------------------------------------------------------
# Deploy AKS cluster using the azure-aks module
# Includes system node pool (for system workloads) and worker node pool (for application workloads)
module "aks_cluster" {
  source = "../../modules/azure-aks"

  aks_name            = var.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_dns_prefix
  sku_tier            = var.aks_sku_tier
  kubernetes_version  = var.aks_kubernetes_version
  aks_subnet_id       = azurerm_subnet.aks.id

  # System Node Pool Configuration
  system_node_pool_name           = var.aks_system_node_pool_name
  system_node_pool_count          = var.aks_system_node_pool_count
  system_node_pool_vm_size        = var.aks_system_node_pool_vm_size
  system_node_pool_os_disk_size_gb = var.aks_system_node_pool_os_disk_size_gb
  system_node_pool_os_disk_type   = var.aks_system_node_pool_os_disk_type

  # Worker Node Pool Configuration
  worker_node_pool_name           = var.aks_worker_node_pool_name
  worker_node_pool_count          = var.aks_worker_node_pool_count
  worker_node_pool_vm_size        = var.aks_worker_node_pool_vm_size
  worker_node_pool_os_disk_size_gb = var.aks_worker_node_pool_os_disk_size_gb
  worker_node_pool_os_disk_type   = var.aks_worker_node_pool_os_disk_type

  # Network Configuration
  network_plugin = var.aks_network_plugin
  network_policy = var.aks_network_policy
  service_cidr   = var.aks_service_cidr
  dns_service_ip = var.aks_dns_service_ip

  # Security Configuration
  enable_azure_ad_rbac    = var.aks_enable_azure_ad_rbac
  tenant_id               = var.aks_enable_azure_ad_rbac ? var.tenant_id : null
  private_cluster_enabled = var.aks_private_cluster_enabled

  # Monitoring Configuration
  enable_monitoring           = var.aks_enable_monitoring
  log_analytics_workspace_id  = var.aks_enable_monitoring ? var.aks_log_analytics_workspace_id : null

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "kubernetes"
    }
  )
}
