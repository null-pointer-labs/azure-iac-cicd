# ===================================================================
# Azure Key Vault Module - Outputs
# ===================================================================
# Exports important resource attributes for use by calling modules
# ===================================================================

output "keyvault_id" {
  description = "The ID of the Azure Key Vault"
  value       = azurerm_key_vault.main.id
}

output "keyvault_name" {
  description = "The name of the Azure Key Vault"
  value       = azurerm_key_vault.main.name
}

output "keyvault_uri" {
  description = "The URI of the Key Vault for accessing keys, secrets, and certificates"
  value       = azurerm_key_vault.main.vault_uri
}

output "tenant_id" {
  description = "The Azure Active Directory tenant ID for the Key Vault"
  value       = azurerm_key_vault.main.tenant_id
}

output "sku_name" {
  description = "The SKU tier of the Key Vault (standard or premium)"
  value       = azurerm_key_vault.main.sku_name
}

output "private_endpoint_id" {
  description = "ID of the Private Endpoint (if created)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.keyvault[0].id : null
}

output "pe_private_ip" {
  description = "Private IP address of the Private Endpoint (for DNS registration)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.keyvault[0].private_service_connection[0].private_ip_address : null
}
