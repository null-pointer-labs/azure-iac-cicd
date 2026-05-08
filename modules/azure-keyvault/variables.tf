# ===================================================================
# Azure Key Vault Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the Key Vault module
# ===================================================================

variable "keyvault_name" {
  description = "Name of the Azure Key Vault (must be globally unique, 3-24 characters, alphanumeric and hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.keyvault_name)) && length(var.keyvault_name) >= 3 && length(var.keyvault_name) <= 24
    error_message = "Key Vault name must be alphanumeric with hyphens, between 3-24 characters."
  }
}

variable "location" {
  description = "Azure region where the Key Vault will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Key Vault will be created"
  type        = string
}

# -------------------------------------------------------------------
# SKU Configuration (Cost-Affecting)
# -------------------------------------------------------------------

variable "sku_name" {
  description = "SKU tier for the Key Vault (standard or premium). Premium includes HSM-backed keys support (significantly higher cost)."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be either 'standard' or 'premium'."
  }
}

# -------------------------------------------------------------------
# Security and Compliance Settings
# -------------------------------------------------------------------

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted Key Vault items (7-90 days)"
  type        = number
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (prevents permanent deletion during retention period)"
  type        = bool
  default     = false
}

variable "enabled_for_deployment" {
  description = "Allow Azure Virtual Machines to retrieve certificates from the Key Vault"
  type        = bool
  default     = false
}

variable "enabled_for_disk_encryption" {
  description = "Allow Azure Disk Encryption to retrieve secrets and unwrap keys"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "Allow Azure Resource Manager to retrieve secrets from the Key Vault during deployment"
  type        = bool
  default     = false
}

# -------------------------------------------------------------------
# Networking Configuration
# -------------------------------------------------------------------

variable "enable_private_endpoint" {
  description = "Enable Private Endpoint for the Key Vault"
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

variable "public_network_access_enabled" {
  description = "Enable public network access to the Key Vault (recommended: false when using Private Endpoints)"
  type        = bool
  default     = true
}

variable "network_acls_enabled" {
  description = "Enable network ACL configuration (not needed when using Private Endpoints exclusively)"
  type        = bool
  default     = false
}

variable "network_acls_default_action" {
  description = "Default action for network ACLs (Allow or Deny)"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_acls_default_action)
    error_message = "Network ACL default action must be either 'Allow' or 'Deny'."
  }
}

variable "network_acls_bypass" {
  description = "Which Azure services are allowed to bypass network rules (AzureServices or None)"
  type        = string
  default     = "AzureServices"

  validation {
    condition     = contains(["AzureServices", "None"], var.network_acls_bypass)
    error_message = "Network ACL bypass must be either 'AzureServices' or 'None'."
  }
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges (CIDR notation) for Key Vault access"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the Key Vault"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------
# Access Policy Configuration
# -------------------------------------------------------------------

variable "create_deployer_access_policy" {
  description = "Create an access policy for the current deployer (user or service principal)"
  type        = bool
  default     = true
}

variable "access_policies" {
  description = "List of additional access policies to create for the Key Vault"
  type = list(object({
    object_id               = string
    key_permissions         = list(string)
    secret_permissions      = list(string)
    certificate_permissions = list(string)
  }))
  default = []
}

# -------------------------------------------------------------------
# Tagging
# -------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
