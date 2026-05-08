# ===================================================================
# Azure Redis Cache Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the Redis Cache module
# ===================================================================

variable "redis_name" {
  description = "Name of the Azure Redis Cache (must be globally unique, alphanumeric and hyphens only)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.redis_name)) && length(var.redis_name) >= 1 && length(var.redis_name) <= 63
    error_message = "Redis name must be alphanumeric with hyphens, between 1-63 characters."
  }
}

variable "location" {
  description = "Azure region where the Redis Cache will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Redis Cache will be created"
  type        = string
}

# -------------------------------------------------------------------
# SKU Configuration (Cost-Affecting)
# -------------------------------------------------------------------

variable "sku_name" {
  description = "SKU tier for Redis Cache (Basic, Standard, or Premium). Basic = No SLA, Standard = SLA with replication, Premium = Standard + clustering/persistence/VNet"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "family" {
  description = "SKU family for Redis Cache. Use 'C' for Basic/Standard, 'P' for Premium"
  type        = string
  default     = "C"

  validation {
    condition     = contains(["C", "P"], var.family)
    error_message = "Family must be 'C' (Basic/Standard) or 'P' (Premium)."
  }
}

variable "capacity" {
  description = "Size of Redis Cache. Basic/Standard: 0-6 (250MB-53GB), Premium: 1-4 (6GB-120GB). Affects cost significantly."
  type        = number
  default     = 0

  validation {
    condition     = var.capacity >= 0 && var.capacity <= 6
    error_message = "Capacity must be between 0-6."
  }
}

# -------------------------------------------------------------------
# Networking Configuration
# -------------------------------------------------------------------

variable "enable_private_endpoint" {
  description = "Enable Private Endpoint for the Redis Cache (recommended for production)"
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

variable "subnet_id" {
  description = "ID of the subnet for VNet integration (Premium SKU only)"
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed. Set to false when using Private Endpoint only."
  type        = bool
  default     = true
}

variable "firewall_rules" {
  description = "Map of firewall rules to allow specific IP ranges. Only applicable when public_network_access_enabled is true."
  type = map(object({
    start_ip = string
    end_ip   = string
  }))
  default = {}
}

# -------------------------------------------------------------------
# Security Configuration
# -------------------------------------------------------------------

variable "enable_non_ssl_port" {
  description = "Enable non-SSL port 6379. Should be false for production (uses SSL port 6380 only)."
  type        = bool
  default     = false
}

variable "minimum_tls_version" {
  description = "Minimum TLS version for connections (1.0, 1.1, or 1.2). Use 1.2 for best security."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.0", "1.1", "1.2"], var.minimum_tls_version)
    error_message = "Minimum TLS version must be 1.0, 1.1, or 1.2."
  }
}

variable "enable_authentication" {
  description = "Enable authentication (access key requirement). Should always be true for security."
  type        = bool
  default     = true
}

# -------------------------------------------------------------------
# Redis Configuration
# -------------------------------------------------------------------

variable "redis_version" {
  description = "Redis version (4 or 6). Version 6 is recommended for latest features."
  type        = string
  default     = "6"

  validation {
    condition     = contains(["4", "6"], var.redis_version)
    error_message = "Redis version must be 4 or 6."
  }
}

variable "maxmemory_policy" {
  description = "How Redis evicts keys when max memory is reached. Common: volatile-lru, allkeys-lru, noeviction"
  type        = string
  default     = "volatile-lru"
}

variable "maxmemory_reserved" {
  description = "MB of memory reserved for non-cache usage (fragmentation, replication). Recommended: 10% of cache size."
  type        = number
  default     = null
}

variable "maxmemory_delta" {
  description = "MB of memory reserved per shard for non-cache usage during save operations."
  type        = number
  default     = null
}

variable "maxfragmentationmemory_reserved" {
  description = "MB of memory reserved to accommodate memory fragmentation."
  type        = number
  default     = null
}

# -------------------------------------------------------------------
# Premium Features (Premium SKU Only)
# -------------------------------------------------------------------

variable "shard_count" {
  description = "Number of shards for clustering (Premium SKU only). Enables horizontal scaling."
  type        = number
  default     = null
}

variable "zones" {
  description = "List of availability zones for zone redundancy (Premium SKU only). Example: [\"1\", \"2\"]"
  type        = list(string)
  default     = null
}

variable "rdb_backup_enabled" {
  description = "Enable RDB persistence for data backup (Premium SKU only). Adds cost for storage."
  type        = bool
  default     = false
}

variable "rdb_backup_frequency" {
  description = "RDB backup frequency in minutes (15, 30, 60, 360, 720, 1440). Premium SKU only."
  type        = number
  default     = 60

  validation {
    condition     = var.rdb_backup_frequency == null || contains([15, 30, 60, 360, 720, 1440], var.rdb_backup_frequency)
    error_message = "RDB backup frequency must be 15, 30, 60, 360, 720, or 1440 minutes."
  }
}

variable "rdb_backup_max_snapshot_count" {
  description = "Maximum number of RDB snapshots to retain. Premium SKU only."
  type        = number
  default     = 1
}

variable "rdb_storage_connection_string" {
  description = "Storage account connection string for RDB backups. Premium SKU only."
  type        = string
  default     = null
  sensitive   = true
}

# -------------------------------------------------------------------
# Maintenance Configuration
# -------------------------------------------------------------------

variable "patch_schedule" {
  description = "Maintenance window for patching. Example: { day_of_week = 'Sunday', start_hour_utc = 2 }"
  type = object({
    day_of_week    = string
    start_hour_utc = number
  })
  default = null
}

# -------------------------------------------------------------------
# Identity Configuration
# -------------------------------------------------------------------

variable "identity_type" {
  description = "Type of managed identity (SystemAssigned, UserAssigned, or SystemAssigned, UserAssigned)"
  type        = string
  default     = null

  validation {
    condition     = var.identity_type == null || contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity_type)
    error_message = "Identity type must be SystemAssigned, UserAssigned, or SystemAssigned, UserAssigned."
  }
}

variable "identity_ids" {
  description = "List of user-assigned identity IDs (required when identity_type includes UserAssigned)"
  type        = list(string)
  default     = null
}

# -------------------------------------------------------------------
# Tagging
# -------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
