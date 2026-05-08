# ===================================================================
# Azure Container Registry Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the ACR module
# ===================================================================

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, alphanumeric only)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+$", var.acr_name)) && length(var.acr_name) >= 5 && length(var.acr_name) <= 50
    error_message = "ACR name must be alphanumeric only, between 5-50 characters."
  }
}

variable "location" {
  description = "Azure region where the ACR will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the ACR will be created"
  type        = string
}

variable "enable_private_endpoint" {
  description = "Enable Private Endpoint for the container registry"
  type        = bool
  default     = false
}

variable "pe_subnet_id" {
  description = "ID of the subnet for Private Endpoint (required when enable_private_endpoint is true)"
  type        = string
  default     = null
}

variable "vnet_id" {
  description = "ID of the Virtual Network for Private DNS Zone link (required when enable_private_endpoint is true)"
  type        = string
  default     = null
}

variable "pe_resource_group_name" {
  description = "Name of the resource group where the Private Endpoint will be created (typically the network RG)"
  type        = string
  default     = null
}

variable "sku" {
  description = "SKU tier for the container registry (Basic, Standard, or Premium). Premium is required for Private Endpoints."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be one of: Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user for the registry (not recommended for production)"
  type        = bool
  default     = false
}

variable "georeplications" {
  description = "List of regions for geo-replication (Premium SKU only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

variable "network_rule_set_enabled" {
  description = "Enable network rule set configuration (Premium SKU only, not needed when using Private Endpoints)"
  type        = bool
  default     = false
}

variable "network_rule_default_action" {
  description = "Default action for network rules (Allow or Deny)"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_rule_default_action)
    error_message = "Network rule default action must be either Allow or Deny."
  }
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges (CIDR notation) for registry access"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "[DEPRECATED - Not supported in azurerm provider 4.0+] List of subnet IDs allowed to access the registry. Use Private Endpoints instead for subnet-level access control."
  type        = list(string)
  default     = []
}

variable "public_network_access_enabled" {
  description = "Enable public network access to the registry (recommended: false when using Private Endpoints)"
  type        = bool
  default     = false
}

variable "data_endpoint_enabled" {
  description = "Enable dedicated data endpoints for the container registry (Premium SKU only)"
  type        = bool
  default     = true
}

variable "encryption_enabled" {
  description = "Enable customer-managed key encryption (Premium SKU only)"
  type        = bool
  default     = false
}

variable "key_vault_key_id" {
  description = "Key Vault key ID for encryption (required if encryption_enabled is true)"
  type        = string
  default     = null
}

variable "encryption_identity_client_id" {
  description = "Client ID of the user-assigned identity for encryption"
  type        = string
  default     = null
}

variable "identity_type" {
  description = "Type of managed identity (SystemAssigned, UserAssigned, or SystemAssigned, UserAssigned)"
  type        = string
  default     = null

  validation {
    condition     = var.identity_type == null || contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity_type)
    error_message = "Identity type must be SystemAssigned, UserAssigned, or 'SystemAssigned, UserAssigned'."
  }
}

variable "identity_ids" {
  description = "List of user-assigned identity IDs (required if identity_type includes UserAssigned)"
  type        = list(string)
  default     = null
}

variable "retention_policy_enabled" {
  description = "Enable retention policy for untagged manifests (Premium SKU only)"
  type        = bool
  default     = false
}

variable "retention_policy_days" {
  description = "Number of days to retain untagged manifests (7-365 days)"
  type        = number
  default     = 7

  validation {
    condition     = var.retention_policy_days >= 7 && var.retention_policy_days <= 365
    error_message = "Retention policy days must be between 7 and 365."
  }
}

variable "trust_policy_enabled" {
  description = "Enable content trust policy (Premium SKU only)"
  type        = bool
  default     = false
}

variable "zone_redundancy_enabled" {
  description = "Enable zone redundancy for the registry (Premium SKU only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the container registry"
  type        = map(string)
  default     = {}
}
