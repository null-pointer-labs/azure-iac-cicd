
# -------------------------------------------------------------------
# Azure Key Vault
# -------------------------------------------------------------------
# Deploy Key Vault using the azure-keyvault module with Private Endpoint
module "key_vault" {
  source = "../../modules/azure-keyvault"

  keyvault_name       = var.keyvault_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku_name            = var.keyvault_sku_name

  # Security Configuration
  soft_delete_retention_days = var.keyvault_soft_delete_days
  purge_protection_enabled   = var.keyvault_purge_protection

  # Private Endpoint configuration
  enable_private_endpoint = var.keyvault_enable_private_endpoint
  pe_subnet_id            = var.keyvault_enable_private_endpoint ? azurerm_subnet.app.id : null
  pe_resource_group_name  = var.keyvault_enable_private_endpoint ? azurerm_resource_group.network.name : null
  vnet_id                 = var.keyvault_enable_private_endpoint ? azurerm_virtual_network.main.id : null

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "key-vault"
    }
  )
}
