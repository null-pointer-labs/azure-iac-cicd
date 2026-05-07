
# -------------------------------------------------------------------
# Azure Cosmos DB
# -------------------------------------------------------------------
# Deploy Cosmos DB with MongoDB API using the azure-cosmosdb module
module "cosmos_db" {
  source = "../../modules/azure-cosmosdb"

  cosmosdb_account_name = var.cosmosdb_account_name
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name

  # Throughput Configuration
  throughput_mode = var.cosmosdb_throughput_mode
  max_throughput  = var.cosmosdb_max_throughput

  # MongoDB Configuration
  mongo_server_version = var.cosmosdb_mongo_server_version

  # Features Configuration
  enable_analytical_storage = var.cosmosdb_enable_analytical_storage

  # Backup Configuration
  backup_type                = var.cosmosdb_backup_type
  backup_interval_minutes    = var.cosmosdb_backup_interval_minutes
  backup_retention_hours     = var.cosmosdb_backup_retention_hours
  backup_storage_redundancy  = var.cosmosdb_backup_storage_redundancy

  # Network Configuration
  public_network_access_enabled = var.cosmosdb_public_network_access_enabled
  enable_private_endpoint       = var.cosmosdb_enable_private_endpoint
  private_endpoint_subnet_id    = var.cosmosdb_enable_private_endpoint ? azurerm_subnet.pe.id : null
  vnet_id                       = var.cosmosdb_enable_private_endpoint ? azurerm_virtual_network.main.id : null

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "cosmosdb"
    }
  )
}
