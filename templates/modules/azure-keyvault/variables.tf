
# ===================================================================
# Azure Key Vault Module Variables
# ===================================================================

variable "keyvault_name" {
  description = "Name of the Key Vault (must be globally unique, 3-24 characters)"
  type        = string
}

variable "keyvault_sku_name" {
  description = "SKU name for Key Vault (standard or premium)"
  type        = string
  default     = "standard"
}

variable "keyvault_enable_private_endpoint" {
  description = "Enable Private Endpoint for secure access"
  type        = bool
  default     = true
}

variable "keyvault_purge_protection" {
  description = "Enable purge protection to prevent permanent deletion"
  type        = bool
  default     = false
}

variable "keyvault_soft_delete_days" {
  description = "Number of days to retain deleted items (7-90 days)"
  type        = number
  default     = 90
}
