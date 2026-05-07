
# ===================================================================
# Azure Redis Cache Module Variables
# ===================================================================

variable "redis_name" {
  description = "Name of the Redis Cache (must be globally unique)"
  type        = string
}

variable "redis_sku_name" {
  description = "SKU name for Redis Cache (Basic, Standard, or Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis capacity (0-6 for C family, 1-5 for P family)"
  type        = number
  default     = 3
}

variable "redis_enable_private_endpoint" {
  description = "Enable Private Endpoint for secure VNet access"
  type        = bool
  default     = true
}
