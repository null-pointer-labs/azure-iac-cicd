# ===================================================================
# Azure Key Vault Module - Main Resources
# ===================================================================
# This module creates an Azure Key Vault with configurable
# SKU, networking, and security settings
# ===================================================================

# -------------------------------------------------------------------
# Data Source: Current Client Configuration
# -------------------------------------------------------------------
# Required to get tenant_id for Key Vault configuration
data "azurerm_client_config" "current" {}

# -------------------------------------------------------------------
# Azure Key Vault
# -------------------------------------------------------------------
# Creates a Key Vault for storing secrets, keys, and certificates
resource "azurerm_key_vault" "main" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.sku_name

  # Soft delete and purge protection settings
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Azure service integration flags
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment

  # Public network access control
  public_network_access_enabled = var.public_network_access_enabled

  # Network ACLs (when not using Private Endpoints exclusively)
  dynamic "network_acls" {
    for_each = var.network_acls_enabled && !var.enable_private_endpoint ? [1] : []
    content {
      default_action             = var.network_acls_default_action
      bypass                     = var.network_acls_bypass
      ip_rules                   = var.allowed_ip_ranges
      virtual_network_subnet_ids = var.allowed_subnet_ids
    }
  }

  # Tags
  tags = var.tags
}

# -------------------------------------------------------------------
# Key Vault Access Policy for Current User/Service Principal
# -------------------------------------------------------------------
# Grants the deploying user/service principal full access to manage the Key Vault
resource "azurerm_key_vault_access_policy" "deployer" {
  count = var.create_deployer_access_policy ? 1 : 0

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import",
    "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey",
    "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy",
    "SetRotationPolicy"
  ]

  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]

  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers",
    "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers",
    "Purge", "Recover", "Restore", "SetIssuers", "Update"
  ]
}

# -------------------------------------------------------------------
# Additional Access Policies
# -------------------------------------------------------------------
# Create additional access policies for other users/applications
resource "azurerm_key_vault_access_policy" "additional" {
  for_each = { for idx, policy in var.access_policies : idx => policy }

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.object_id

  key_permissions         = each.value.key_permissions
  secret_permissions      = each.value.secret_permissions
  certificate_permissions = each.value.certificate_permissions
}

# -------------------------------------------------------------------
# Private Endpoint (Optional)
# -------------------------------------------------------------------
# Creates a Private Endpoint for secure, private access to Key Vault
# DNS registration is handled separately by private-dns-* modules
resource "azurerm_private_endpoint" "keyvault" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "${var.keyvault_name}-pe"
  location            = var.location
  resource_group_name = coalesce(var.pe_resource_group_name, var.resource_group_name)
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "${var.keyvault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = var.tags
}
