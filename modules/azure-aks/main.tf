# ===================================================================
# Azure Kubernetes Service (AKS) Module - Main Resources
# ===================================================================
# This module creates an AKS cluster with configurable node pools,
# networking, and security settings
# ===================================================================

# -------------------------------------------------------------------
# Azure Kubernetes Service Cluster
# -------------------------------------------------------------------
# Creates an AKS cluster with a default system node pool
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  sku_tier            = var.sku_tier
  kubernetes_version  = var.kubernetes_version

  # Default System Node Pool
  # This is the initial node pool and must be of type "System"
  default_node_pool {
    name                = var.system_node_pool_name
    node_count          = var.system_node_pool_count
    vm_size             = var.system_node_pool_vm_size
    os_disk_size_gb     = var.system_node_pool_os_disk_size_gb
    os_disk_type        = var.system_node_pool_os_disk_type
    vnet_subnet_id      = var.aks_subnet_id
    type                = "VirtualMachineScaleSets"

    # Node labels for workload scheduling
    node_labels = {
      "role" = "system"
    }

    # Zones for high availability (optional)
    zones = var.system_node_pool_zones

    # Upgrade settings to control node pool upgrade behavior
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  # Identity configuration
  # Using SystemAssigned managed identity for AKS to manage Azure resources
  identity {
    type = "SystemAssigned"
  }

  # Network Configuration
  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
  }

  # Azure AD integration (optional but recommended for RBAC)
  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_azure_ad_rbac ? [1] : []
    content {
      azure_rbac_enabled     = true
      tenant_id              = var.tenant_id
    }
  }

  # Private cluster configuration (optional)
  private_cluster_enabled = var.private_cluster_enabled

  # Monitoring and logging
  dynamic "oms_agent" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Additional Worker Node Pool
# -------------------------------------------------------------------
# Creates an additional node pool for worker workloads
resource "azurerm_kubernetes_cluster_node_pool" "worker" {
  name                  = var.worker_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.worker_node_pool_vm_size
  node_count            = var.worker_node_pool_count
  os_disk_size_gb       = var.worker_node_pool_os_disk_size_gb
  os_disk_type          = var.worker_node_pool_os_disk_type
  vnet_subnet_id        = var.aks_subnet_id

  # Node labels for workload scheduling
  node_labels = {
    "role" = "worker"
  }

  # Zones for high availability (optional)
  zones = var.worker_node_pool_zones

  # Upgrade settings to control node pool upgrade behavior
  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Private Endpoint for AKS API Server (Optional)
# -------------------------------------------------------------------
# When private_cluster_enabled is false but you want Private Endpoint access
# Note: Private clusters already have private access built-in
# This is an additional configuration for hybrid scenarios
