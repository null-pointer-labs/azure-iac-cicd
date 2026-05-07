# ===================================================================
# Private DNS Registration Module - Main Configuration
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Purpose: Register Private Endpoint IP in an EXISTING Private DNS Zone
# Scenario: Cross-subscription DNS management
# 
# Prerequisites (managed externally, NOT by this module):
#   ✓ Private DNS Zone already exists in DNS subscription
#   ✓ VNet Link between DNS Zone and service VNet already exists
# 
# This module creates ONLY:
#   - DNS A Record pointing PE private IP to the service resource name
# 
# Provider requirement: Requires 'azurerm.dns_sub' provider alias
# ===================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.dns_sub]
    }
  }
}

# ===================================================================
# Data Source: Reference EXISTING Private DNS Zone
# ===================================================================
# Uses cross-subscription provider alias to access DNS Zone
# in a different subscription from the service resources
# ===================================================================

data "azurerm_private_dns_zone" "existing" {
  provider            = azurerm.dns_sub
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_rg
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
  provider            = azurerm.dns_sub
  name                = var.record_name
  zone_name           = data.azurerm_private_dns_zone.existing.name
  resource_group_name = var.dns_zone_rg
  ttl                 = var.ttl
  records             = [var.private_ip_address]
  tags                = var.tags
}
