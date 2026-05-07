# ===================================================================
# Private DNS Standalone Module - Main Configuration
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Purpose: Create Private DNS Zone and register Private Endpoint IP
# Scenario: Same-subscription DNS management (standalone)
# 
# This module creates ALL DNS resources:
#   ✓ Private DNS Zone (new zone in service subscription)
#   ✓ VNet Link (links zone to service VNet)
#   ✓ DNS A Record (maps service name to PE private IP)
# 
# Provider requirement: Uses default 'azurerm' provider (same subscription)
# ===================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ===================================================================
# Resource: Private DNS Zone
# ===================================================================
# Creates a new Private DNS Zone in the service subscription
# 
# Example zones by service:
#   - privatelink.azurecr.io                     (Azure Container Registry)
#   - privatelink.vaultcore.azure.net            (Azure Key Vault)
#   - privatelink.mongo.cosmos.azure.com         (Cosmos DB - MongoDB)
#   - privatelink.documents.azure.com            (Cosmos DB - SQL)
#   - privatelink.blob.core.windows.net          (Storage - Blob)
#   - privatelink.servicebus.windows.net         (Service Bus)
# ===================================================================

resource "azurerm_private_dns_zone" "zone" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_rg
  tags                = var.tags
}

# ===================================================================
# Resource: Virtual Network Link
# ===================================================================
# Links the Private DNS Zone to the service VNet
# Enables DNS resolution for Private Endpoint within the VNet
# ===================================================================

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "vnet-link-${replace(var.dns_zone_name, ".", "-")}"
  resource_group_name   = var.dns_zone_rg
  private_dns_zone_name = azurerm_private_dns_zone.zone.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = var.vnet_link_registration_enabled
  tags                  = var.tags
}

# ===================================================================
# Resource: DNS A Record for Private Endpoint
# ===================================================================
# Creates an A record mapping the service resource name to the
# Private Endpoint's private IP address
# 
# Example mappings:
#   - myacr.privatelink.azurecr.io → 10.10.2.5
#   - mykeyvault.privatelink.vaultcore.azure.net → 10.10.2.6
#   - mycosmosdb.privatelink.mongo.cosmos.azure.com → 10.10.2.7
# ===================================================================

resource "azurerm_private_dns_a_record" "pe_record" {
  name                = var.record_name
  zone_name           = azurerm_private_dns_zone.zone.name
  resource_group_name = var.dns_zone_rg
  ttl                 = var.ttl
  records             = [var.private_ip_address]
  tags                = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.vnet_link]
}
