# ===================================================================
# Azure Cosmos DB Module - Main Resources
# ===================================================================
# This module creates an Azure Cosmos DB account with MongoDB API,
# configurable throughput, backup, and analytical storage
# ===================================================================

# -------------------------------------------------------------------
# Azure Cosmos DB Account
# -------------------------------------------------------------------
# Creates a Cosmos DB account with MongoDB API for document storage
resource "azurerm_cosmosdb_account" "main" {
  name                = var.cosmosdb_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  # Consistency policy for MongoDB
  # Session consistency provides a balance between performance and consistency
  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.consistency_level == "BoundedStaleness" ? var.max_interval_in_seconds : null
    max_staleness_prefix    = var.consistency_level == "BoundedStaleness" ? var.max_staleness_prefix : null
  }

  # Geographic location configuration
  # Single region write configuration for cost optimization
  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # MongoDB API capabilities
  capabilities {
    name = "EnableMongo"
  }

  # Enable server-side retry for write operations
  capabilities {
    name = "DisableRateLimitingResponses"
  }

  # MongoDB version
  mongo_server_version = var.mongo_server_version

  # Backup configuration
  backup {
    type                = var.backup_type
    interval_in_minutes = var.backup_type == "Periodic" ? var.backup_interval_minutes : null
    retention_in_hours  = var.backup_type == "Periodic" ? var.backup_retention_hours : null
    storage_redundancy  = var.backup_type == "Periodic" ? var.backup_storage_redundancy : null
  }

  # Network and security settings
  public_network_access_enabled     = var.public_network_access_enabled
  is_virtual_network_filter_enabled = var.enable_virtual_network_filter
  
  # IP firewall rules
  ip_range_filter = length(var.ip_range_filter) > 0 ? var.ip_range_filter : []

  # Virtual network rules (for subnet-based access)
  dynamic "virtual_network_rule" {
    for_each = var.virtual_network_subnet_ids
    content {
      id = virtual_network_rule.value
    }
  }

  # Analytical storage schema type
  analytical_storage_enabled = var.enable_analytical_storage

  # Free tier (first 1000 RU/s and 25 GB storage are free)
  free_tier_enabled = var.enable_free_tier

  # Automatic failover for multi-region deployments
  automatic_failover_enabled = var.enable_automatic_failover

  # Resource tags
  tags = var.tags
}

# -------------------------------------------------------------------
# MongoDB Database
# -------------------------------------------------------------------
# Creates a MongoDB database within the Cosmos DB account
resource "azurerm_cosmosdb_mongo_database" "main" {
  count = var.create_default_database ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name

  # Throughput configuration
  # Autoscale provides automatic scaling between 10% and 100% of max throughput
  dynamic "autoscale_settings" {
    for_each = var.throughput_mode == "autoscale" ? [1] : []
    content {
      max_throughput = var.max_throughput
    }
  }

  # Manual throughput (fixed RU/s)
  throughput = var.throughput_mode == "manual" ? var.manual_throughput : null
}

# -------------------------------------------------------------------
# Private Endpoint (Optional)
# -------------------------------------------------------------------
# Creates a private endpoint for secure access from a VNet
# DNS registration is handled separately by private-dns-* modules
resource "azurerm_private_endpoint" "cosmosdb" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "${var.cosmosdb_account_name}-pe"
  location            = var.location
  resource_group_name = coalesce(var.pe_resource_group_name, var.resource_group_name)
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.cosmosdb_account_name}-psc"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

  tags = var.tags
}
