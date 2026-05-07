# ===================================================================
# Azure Cosmos DB Module - Outputs
# ===================================================================
# Exports important resource attributes for use by calling modules
# ===================================================================

output "cosmosdb_account_id" {
  description = "The ID of the Azure Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmosdb_account_name" {
  description = "The name of the Azure Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmosdb_endpoint" {
  description = "The endpoint URL for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmosdb_primary_key" {
  description = "The primary master key for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "cosmosdb_secondary_key" {
  description = "The secondary master key for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.secondary_key
  sensitive   = true
}

output "cosmosdb_primary_readonly_key" {
  description = "The primary read-only key for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.primary_readonly_key
  sensitive   = true
}

output "cosmosdb_secondary_readonly_key" {
  description = "The secondary read-only key for the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.secondary_readonly_key
  sensitive   = true
}

output "cosmosdb_connection_strings" {
  description = "List of connection strings for the Cosmos DB account"
  value       = [azurerm_cosmosdb_account.main.primary_mongodb_connection_string, azurerm_cosmosdb_account.main.secondary_mongodb_connection_string]
  sensitive   = true
}

output "cosmosdb_primary_mongodb_connection_string" {
  description = "Primary MongoDB connection string"
  value       = azurerm_cosmosdb_account.main.primary_mongodb_connection_string
  sensitive   = true
}

output "cosmosdb_database_id" {
  description = "The ID of the MongoDB database (if created)"
  value       = var.create_default_database ? azurerm_cosmosdb_mongo_database.main[0].id : null
}

output "cosmosdb_database_name" {
  description = "The name of the MongoDB database (if created)"
  value       = var.create_default_database ? azurerm_cosmosdb_mongo_database.main[0].name : null
}

output "private_endpoint_id" {
  description = "The ID of the Private Endpoint (if created)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.cosmosdb[0].id : null
}

output "pe_private_ip" {
  description = "The private IP address of the Private Endpoint (for DNS registration)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.cosmosdb[0].private_service_connection[0].private_ip_address : null
}
