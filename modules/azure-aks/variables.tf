# ===================================================================
# Azure Kubernetes Service (AKS) Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the AKS module
# Only exposing variables that are non-default, required, or affect cost
# ===================================================================

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.aks_name)) && length(var.aks_name) >= 1 && length(var.aks_name) <= 63
    error_message = "AKS name must be alphanumeric with hyphens, between 1-63 characters."
  }
}

variable "location" {
  description = "Azure region where the AKS cluster will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the AKS cluster will be created"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "sku_tier" {
  description = "SKU tier for the AKS cluster (Free, Standard, Premium). Standard/Premium provide SLA guarantees."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "SKU tier must be Free, Standard, or Premium."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster (e.g., 1.28, 1.29)"
  type        = string
  default     = null # Uses default Azure-supported version
}

variable "aks_subnet_id" {
  description = "ID of the subnet where AKS nodes will be deployed"
  type        = string
}

# ===================================================================
# System Node Pool Configuration
# ===================================================================

variable "system_node_pool_name" {
  description = "Name of the system node pool (max 12 characters, lowercase alphanumeric)"
  type        = string
  default     = "systempool"

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.system_node_pool_name))
    error_message = "System node pool name must be lowercase alphanumeric, max 12 characters."
  }
}

variable "system_node_pool_count" {
  description = "Number of nodes in the system node pool (affects cost)"
  type        = number
  default     = 2
}

variable "system_node_pool_vm_size" {
  description = "VM size for system node pool (affects cost). Example: Standard_F4s_v2, Standard_D2s_v3"
  type        = string
  default     = "Standard_F4s_v2"
}

variable "system_node_pool_os_disk_size_gb" {
  description = "OS disk size in GB for system nodes (affects cost). Minimum 30 GB."
  type        = number
  default     = 128
}

variable "system_node_pool_os_disk_type" {
  description = "OS disk type for system nodes (Managed, Ephemeral). Managed uses persistent disks."
  type        = string
  default     = "Managed"

  validation {
    condition     = contains(["Managed", "Ephemeral"], var.system_node_pool_os_disk_type)
    error_message = "OS disk type must be Managed or Ephemeral."
  }
}

variable "system_node_pool_zones" {
  description = "Availability zones for system node pool (affects availability and cost)"
  type        = list(string)
  default     = null
}

# ===================================================================
# Worker Node Pool Configuration
# ===================================================================

variable "worker_node_pool_name" {
  description = "Name of the worker node pool (max 12 characters, lowercase alphanumeric)"
  type        = string
  default     = "workerpool"

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.worker_node_pool_name))
    error_message = "Worker node pool name must be lowercase alphanumeric, max 12 characters."
  }
}

variable "worker_node_pool_count" {
  description = "Number of nodes in the worker node pool (affects cost)"
  type        = number
  default     = 3
}

variable "worker_node_pool_vm_size" {
  description = "VM size for worker node pool (affects cost). Example: Standard_DS3_v2, Standard_D4s_v3"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "worker_node_pool_os_disk_size_gb" {
  description = "OS disk size in GB for worker nodes (affects cost). Minimum 30 GB."
  type        = number
  default     = 128
}

variable "worker_node_pool_os_disk_type" {
  description = "OS disk type for worker nodes (Managed, Ephemeral). Managed uses persistent disks."
  type        = string
  default     = "Managed"

  validation {
    condition     = contains(["Managed", "Ephemeral"], var.worker_node_pool_os_disk_type)
    error_message = "OS disk type must be Managed or Ephemeral."
  }
}

variable "worker_node_pool_zones" {
  description = "Availability zones for worker node pool (affects availability and cost)"
  type        = list(string)
  default     = null
}

# ===================================================================
# Network Configuration
# ===================================================================

variable "network_plugin" {
  description = "Network plugin for AKS (azure, kubenet)"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be azure or kubenet."
  }
}

variable "network_policy" {
  description = "Network policy plugin (azure, calico, cilium). Requires network_plugin = azure"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "Network policy must be azure, calico, or cilium."
  }
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services (must not overlap with VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

# ===================================================================
# Security and Access Configuration
# ===================================================================

variable "enable_azure_ad_rbac" {
  description = "Enable Azure AD RBAC for cluster access control"
  type        = bool
  default     = false
}

variable "tenant_id" {
  description = "Azure AD tenant ID (required when enable_azure_ad_rbac is true)"
  type        = string
  default     = null
}

variable "private_cluster_enabled" {
  description = "Enable private cluster (API server only accessible via private network)"
  type        = bool
  default     = false
}

# ===================================================================
# Monitoring Configuration
# ===================================================================

variable "enable_monitoring" {
  description = "Enable Azure Monitor Container Insights (affects cost)"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring (required when enable_monitoring is true)"
  type        = string
  default     = null
}

# ===================================================================
# Tags
# ===================================================================

variable "tags" {
  description = "Tags to apply to all AKS resources"
  type        = map(string)
  default     = {}
}
