
# ===================================================================
# Azure Kubernetes Service (AKS) Module Variables
# ===================================================================

variable "aks_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "aks_sku_tier" {
  description = "SKU tier for the AKS cluster (Free or Standard)"
  type        = string
  default     = "Standard"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = null
}

# System Node Pool Variables
variable "aks_system_node_pool_name" {
  description = "Name of the system node pool"
  type        = string
  default     = "systempool"
}

variable "aks_system_node_pool_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "aks_system_node_pool_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_F4s_v2"
}

variable "aks_system_node_pool_os_disk_size_gb" {
  description = "OS disk size in GB for system node pool"
  type        = number
  default     = 1024
}

variable "aks_system_node_pool_os_disk_type" {
  description = "OS disk type for system node pool"
  type        = string
  default     = "Managed"
}

# Worker Node Pool Variables
variable "aks_worker_node_pool_name" {
  description = "Name of the worker node pool"
  type        = string
  default     = "workerpool"
}

variable "aks_worker_node_pool_count" {
  description = "Number of nodes in the worker node pool"
  type        = number
  default     = 3
}

variable "aks_worker_node_pool_vm_size" {
  description = "VM size for worker node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "aks_worker_node_pool_os_disk_size_gb" {
  description = "OS disk size in GB for worker node pool"
  type        = number
  default     = 1024
}

variable "aks_worker_node_pool_os_disk_type" {
  description = "OS disk type for worker node pool"
  type        = string
  default     = "Managed"
}

# Network Variables
variable "aks_network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "aks_network_policy" {
  description = "Network policy for AKS (azure or calico)"
  type        = string
  default     = "azure"
}

variable "aks_service_cidr" {
  description = "Service CIDR for Kubernetes services"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "DNS service IP within service_cidr"
  type        = string
  default     = "10.0.0.10"
}

# Security Variables
variable "aks_enable_azure_ad_rbac" {
  description = "Enable Azure AD RBAC for AKS"
  type        = bool
  default     = false
}

variable "aks_private_cluster_enabled" {
  description = "Enable private cluster mode"
  type        = bool
  default     = true
}

# Monitoring Variables
variable "aks_enable_monitoring" {
  description = "Enable Azure Monitor Container Insights"
  type        = bool
  default     = false
}

variable "aks_log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring"
  type        = string
  default     = null
}
