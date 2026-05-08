# ===================================================================
# Azure Redis Cache Module - Outputs
# ===================================================================
# Exports important resource attributes for use by calling modules
# ===================================================================

output "redis_id" {
  description = "The ID of the Azure Redis Cache"
  value       = azurerm_redis_cache.main.id
}

output "redis_name" {
  description = "The name of the Azure Redis Cache"
  value       = azurerm_redis_cache.main.name
}

output "hostname" {
  description = "The hostname of the Redis Cache"
  value       = azurerm_redis_cache.main.hostname
}

output "ssl_port" {
  description = "The SSL port of the Redis Cache (6380)"
  value       = azurerm_redis_cache.main.ssl_port
}

output "port" {
  description = "The non-SSL port of the Redis Cache (6379, only available if enable_non_ssl_port is true)"
  value       = azurerm_redis_cache.main.port
}

output "primary_access_key" {
  description = "The primary access key for the Redis Cache"
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "The secondary access key for the Redis Cache"
  value       = azurerm_redis_cache.main.secondary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "The primary connection string for the Redis Cache"
  value       = azurerm_redis_cache.main.primary_connection_string
  sensitive   = true
}

output "secondary_connection_string" {
  description = "The secondary connection string for the Redis Cache"
  value       = azurerm_redis_cache.main.secondary_connection_string
  sensitive   = true
}

output "identity_principal_id" {
  description = "The Principal ID of the managed identity"
  value       = var.identity_type != null ? azurerm_redis_cache.main.identity[0].principal_id : null
}

output "identity_tenant_id" {
  description = "The Tenant ID of the managed identity"
  value       = var.identity_type != null ? azurerm_redis_cache.main.identity[0].tenant_id : null
}

output "private_endpoint_id" {
  description = "ID of the Private Endpoint (if created)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.redis[0].id : null
}

output "pe_private_ip" {
  description = "Private IP address of the Private Endpoint (if created)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.redis[0].private_service_connection[0].private_ip_address : null
}
