
# ===================================================================
# Azure Container Registry Variables
# ===================================================================

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, alphanumeric only)"
  type        = string
}

variable "acr_sku" {
  description = "SKU tier for the container registry (Basic, Standard, or Premium). Premium is required for Private Endpoints."
  type        = string
  default     = "Premium"
}

variable "acr_enable_private_endpoint" {
  description = "Enable Private Endpoint for secure access to the container registry"
  type        = bool
  default     = true
}

variable "acr_data_endpoint_enabled" {
  description = "Enable dedicated data endpoints for ACR (Premium SKU only)"
  type        = bool
  default     = true
}