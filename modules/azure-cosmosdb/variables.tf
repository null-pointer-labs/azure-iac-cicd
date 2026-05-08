# ===================================================================
# Azure Cosmos DB Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the Cosmos DB module
# Only exposing variables that are non-default, required, or affect cost
# ===================================================================

variable "cosmosdb_account_name" {
  description = "Name of the Azure Cosmos DB account (must be globally unique, lowercase alphanumeric and hyphens only)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cosmosdb_account_name)) && length(var.cosmosdb_account_name) >= 3 && length(var.cosmosdb_account_name) <= 44
    error_message = "Cosmos DB account name must be lowercase alphanumeric with hyphens, between 3-44 characters."
  }
}

variable "location" {
  description = "Azure region where the Cosmos DB account will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Cosmos DB account will be created"
  type        = string
}

# -------------------------------------------------------------------
# Throughput Configuration (Cost-Affecting)
# -------------------------------------------------------------------

variable "throughput_mode" {
  description = "Throughput mode: 'autoscale' (automatic scaling 10%-100%) or 'manual' (fixed RU/s). Autoscale is recommended for variable workloads."
  type        = string
  default     = "autoscale"

  validation {
    condition     = contains(["autoscale", "manual"], var.throughput_mode)
    error_message = "Throughput mode must be 'autoscale' or 'manual'."
  }
}

variable "max_throughput" {
  description = "Maximum throughput (RU/s) for autoscale mode. Actual cost varies from 10%-100% based on usage. Minimum: 1000, must be in increments of 1000."
  type        = number
  default     = 4000

  validation {
    condition     = var.max_throughput >= 1000 && var.max_throughput % 1000 == 0
    error_message = "Max throughput must be at least 1000 and in increments of 1000."
  }
}

variable "manual_throughput" {
  description = "Fixed throughput (RU/s) for manual mode. Only used when throughput_mode is 'manual'. Minimum: 400."
  type        = number
  default     = 400

  validation {
    condition     = var.manual_throughput >= 400
    error_message = "Manual throughput must be at least 400 RU/s."
  }
}

# -------------------------------------------------------------------
# Analytical Storage Configuration (Cost-Affecting)
# -------------------------------------------------------------------

variable "enable_analytical_storage" {
  description = "Enable analytical storage for HTAP scenarios. Adds separate columnar storage for analytical queries. Increases cost based on analytical data size."
  type        = bool
  default     = false
}

# -------------------------------------------------------------------
# Backup Configuration (Cost-Affecting)
# -------------------------------------------------------------------

variable "backup_type" {
  description = "Backup mode: 'Periodic' (scheduled backups) or 'Continuous' (point-in-time restore, higher cost)"
  type        = string
  default     = "Periodic"

  validation {
    condition     = contains(["Periodic", "Continuous"], var.backup_type)
    error_message = "Backup type must be 'Periodic' or 'Continuous'."
  }
}

variable "backup_interval_minutes" {
  description = "Backup interval in minutes for Periodic backup (60-1440). Shorter intervals increase storage costs."
  type        = number
  default     = 240

  validation {
    condition     = var.backup_interval_minutes >= 60 && var.backup_interval_minutes <= 1440
    error_message = "Backup interval must be between 60 and 1440 minutes."
  }
}

variable "backup_retention_hours" {
  description = "Backup retention period in hours for Periodic backup (8-720). Longer retention increases storage costs."
  type        = number
  default     = 720

  validation {
    condition     = var.backup_retention_hours >= 8 && var.backup_retention_hours <= 720
    error_message = "Backup retention must be between 8 and 720 hours (30 days)."
  }
}

variable "backup_storage_redundancy" {
  description = "Backup storage redundancy: 'Geo' (geo-redundant, highest cost), 'Zone' (zone-redundant), or 'Local' (locally redundant, lowest cost)"
  type        = string
  default     = "Geo"

  validation {
    condition     = contains(["Geo", "Zone", "Local"], var.backup_storage_redundancy)
    error_message = "Backup storage redundancy must be 'Geo', 'Zone', or 'Local'."
  }
}

# -------------------------------------------------------------------
# MongoDB Configuration
# -------------------------------------------------------------------

variable "mongo_server_version" {
  description = "MongoDB server version (3.2, 3.6, 4.0, 4.2, 5.0, 6.0). Newer versions provide better features and performance."
  type        = string
  default     = "6.0"

  validation {
    condition     = contains(["3.2", "3.6", "4.0", "4.2", "5.0", "6.0"], var.mongo_server_version)
    error_message = "MongoDB server version must be 3.2, 3.6, 4.0, 4.2, 5.0, or 6.0."
  }
}

variable "create_default_database" {
  description = "Create a default MongoDB database within the account"
  type        = bool
  default     = true
}

variable "database_name" {
  description = "Name of the MongoDB database to create (if create_default_database is true)"
  type        = string
  default     = "main"
}

# -------------------------------------------------------------------
# Consistency Configuration
# -------------------------------------------------------------------

variable "consistency_level" {
  description = "Consistency level: Strong, BoundedStaleness, Session (default, recommended), ConsistentPrefix, or Eventual. Higher consistency increases latency."
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Strong", "BoundedStaleness", "Session", "ConsistentPrefix", "Eventual"], var.consistency_level)
    error_message = "Invalid consistency level."
  }
}

variable "max_interval_in_seconds" {
  description = "Max lag time in seconds for BoundedStaleness consistency (5-86400)"
  type        = number
  default     = 5

  validation {
    condition     = var.max_interval_in_seconds >= 5 && var.max_interval_in_seconds <= 86400
    error_message = "Max interval must be between 5 and 86400 seconds."
  }
}

variable "max_staleness_prefix" {
  description = "Max lag in number of operations for BoundedStaleness consistency (10-2147483647)"
  type        = number
  default     = 100

  validation {
    condition     = var.max_staleness_prefix >= 10 && var.max_staleness_prefix <= 2147483647
    error_message = "Max staleness prefix must be between 10 and 2147483647."
  }
}

# -------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------

variable "public_network_access_enabled" {
  description = "Enable public network access. Disable for production environments using Private Endpoints."
  type        = bool
  default     = true
}

variable "enable_virtual_network_filter" {
  description = "Enable virtual network filtering for subnet-based access control"
  type        = bool
  default     = false
}

variable "ip_range_filter" {
  description = "List of IP addresses or CIDR blocks to allow access (e.g., ['1.2.3.4', '10.0.0.0/24'])"
  type        = list(string)
  default     = []
}

variable "virtual_network_subnet_ids" {
  description = "List of subnet IDs that are allowed to access this Cosmos DB account"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------
# Private Endpoint Configuration
# -------------------------------------------------------------------

variable "enable_private_endpoint" {
  description = "Enable Private Endpoint for secure VNet access. Recommended for production."
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the Private Endpoint will be created (required if enable_private_endpoint is true)"
  type        = string
  default     = null
}
variable "pe_resource_group_name" {
  description = "Name of the resource group where the Private Endpoint will be created (typically the network RG)"
  type        = string
  default     = null
}
variable "create_private_dns_zone" {
  description = "Create and configure private DNS zone for private endpoint resolution"
  type        = bool
  default     = true
}

variable "vnet_id" {
  description = "Virtual Network ID for DNS zone linking (required if create_private_dns_zone is true)"
  type        = string
  default     = null
}

# -------------------------------------------------------------------
# Additional Features
# -------------------------------------------------------------------

variable "enable_free_tier" {
  description = "Enable free tier (first 1000 RU/s and 25 GB storage free). Only one account per subscription can use free tier."
  type        = bool
  default     = false
}

variable "enable_automatic_failover" {
  description = "Enable automatic failover for multi-region deployments"
  type        = bool
  default     = false
}

# -------------------------------------------------------------------
# Resource Tags
# -------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to the Cosmos DB resources"
  type        = map(string)
  default     = {}
}
