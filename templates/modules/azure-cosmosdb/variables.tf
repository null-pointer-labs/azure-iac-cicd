
# ===================================================================
# Azure Cosmos DB Module Variables
# ===================================================================

variable "cosmosdb_account_name" {
  description = "Name of the Cosmos DB account (must be globally unique)"
  type        = string
}

variable "cosmosdb_throughput_mode" {
  description = "Throughput provisioning mode (autoscale or manual)"
  type        = string
  default     = "autoscale"
}

variable "cosmosdb_max_throughput" {
  description = "Maximum throughput in RU/s for autoscale mode"
  type        = number
  default     = 97000
}

variable "cosmosdb_mongo_server_version" {
  description = "MongoDB server version"
  type        = string
  default     = "6.0"
}

variable "cosmosdb_enable_analytical_storage" {
  description = "Enable analytical storage for HTAP scenarios"
  type        = bool
  default     = true
}

variable "cosmosdb_backup_type" {
  description = "Backup type (Periodic or Continuous)"
  type        = string
  default     = "Periodic"
}

variable "cosmosdb_backup_interval_minutes" {
  description = "Backup interval in minutes"
  type        = number
  default     = 240
}

variable "cosmosdb_backup_retention_hours" {
  description = "Backup retention period in hours"
  type        = number
  default     = 720
}

variable "cosmosdb_backup_storage_redundancy" {
  description = "Backup storage redundancy (Geo, Local, or Zone)"
  type        = string
  default     = "Geo"
}

variable "cosmosdb_enable_private_endpoint" {
  description = "Enable Private Endpoint for secure VNet access"
  type        = bool
  default     = true
}

variable "cosmosdb_public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}
