
# ===================================================================
# Azure Kubernetes Service (AKS) Configuration
# ===================================================================
# Standard tier AKS with system and worker node pools
aks_name                        = "aks-__PROJECT_NAME__-__ENV_NAME__"
aks_dns_prefix                  = "aks-__PROJECT_NAME__-__ENV_NAME__"
aks_sku_tier                    = "Standard" # Standard provides 99.95% SLA for API server
aks_kubernetes_version          = null       # Use default Azure-supported version

# System Node Pool Configuration
# 2 x F4s_v2 VMs (4 vCPUs, 8 GB RAM each) with E30 managed OS disks (1024 GB)
aks_system_node_pool_name           = "systempool"
aks_system_node_pool_count          = 2
aks_system_node_pool_vm_size        = "Standard_F4s_v2"
aks_system_node_pool_os_disk_size_gb = 1024 # E30 = 1024 GB Premium SSD
aks_system_node_pool_os_disk_type   = "Managed"

# Worker Node Pool Configuration
# 3 x D4s_v5 VMs (4 vCPUs, 16 GB RAM each) with E30 managed OS disks (1024 GB)
aks_worker_node_pool_name           = "workerpool"
aks_worker_node_pool_count          = 3
aks_worker_node_pool_vm_size        = "Standard_D4s_v5"
aks_worker_node_pool_os_disk_size_gb = 1024 # E30 = 1024 GB Premium SSD
aks_worker_node_pool_os_disk_type   = "Managed"

# Network Configuration
# Using Azure CNI for advanced networking and Azure Network Policy
aks_network_plugin = "azure"
aks_network_policy = "azure"
aks_service_cidr   = "10.0.0.0/16" # Kubernetes services CIDR (separate from VNet)
aks_dns_service_ip = "10.0.0.10"   # DNS service IP within service_cidr

# Security Configuration
aks_enable_azure_ad_rbac    = false # Set to true to enable Azure AD integration
aks_private_cluster_enabled = true  # Private cluster - API server accessible only from VNet

# Monitoring Configuration
aks_enable_monitoring          = false # Set to true to enable Azure Monitor Container Insights
aks_log_analytics_workspace_id = null  # Required when enable_monitoring is true
