# ===================================================================
# Azure Container Registry Module - Outputs
# ===================================================================
# Exports important resource attributes for use by calling modules
# ===================================================================

output "acr_id" {
  description = "The ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "login_server" {
  description = "The URL that can be used to log into the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "The admin username for the container registry (only if admin_enabled is true)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_username : null
}

output "admin_password" {
  description = "The admin password for the container registry (only if admin_enabled is true)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_password : null
  sensitive   = true
}

output "identity_principal_id" {
  description = "The Principal ID of the managed identity"
  value       = var.identity_type != null ? azurerm_container_registry.main.identity[0].principal_id : null
}

output "identity_tenant_id" {
  description = "The Tenant ID of the managed identity"
  value       = var.identity_type != null ? azurerm_container_registry.main.identity[0].tenant_id : null
}

output "private_endpoint_id" {
  description = "ID of the Private Endpoint (if created)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.acr[0].id : null
}

output "pe_private_ip" {
  description = "Private IP address of the Private Endpoint (for DNS registration)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.acr[0].private_service_connection[0].private_ip_address : null
}
