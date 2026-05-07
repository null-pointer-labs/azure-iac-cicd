# ===================================================================
# Private DNS Standalone Module - Variables
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Purpose: Create Private DNS Zone and register Private Endpoint IP
# Scenario: Same-subscription DNS management (standalone)
# 
# This module creates:
#   - Private DNS Zone (scoped to service subscription)
#   - VNet Link (between DNS Zone and service VNet)
#   - A Record pointing to the Private Endpoint's private IP
# 
# Calling pattern: Service modules (ACR, KeyVault, CosmosDB, etc.)
# create their Private Endpoint and pass the PE private IP here
# ===================================================================

variable "private_ip_address" {
  description = "Private IP address of the Private Endpoint (provided by calling service module)"
  type        = string
  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.private_ip_address))
    error_message = "private_ip_address must be a valid IPv4 address."
  }
}

variable "dns_zone_name" {
  description = "Name of the Private DNS Zone to create (e.g., 'privatelink.azurecr.io', 'privatelink.vaultcore.azure.net', 'privatelink.mongo.cosmos.azure.com')"
  type        = string
  validation {
    condition     = can(regex("^privatelink\\.", var.dns_zone_name))
    error_message = "dns_zone_name must start with 'privatelink.' prefix."
  }
}

variable "record_name" {
  description = "Name of the DNS A record (typically the service resource name, e.g., 'myacr', 'mykeyvault', 'mycosmosdb')"
  type        = string
}

variable "dns_zone_rg" {
  description = "Resource Group name where the Private DNS Zone will be created (same subscription as service)"
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the VNet to link with the Private DNS Zone (same subscription as service)"
  type        = string
  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Network/virtualNetworks/.+$", var.vnet_id))
    error_message = "vnet_id must be a valid Azure VNet resource ID."
  }
}

variable "location" {
  description = "Azure region for the Private DNS Zone (should match service location)"
  type        = string
  default     = "global" # Private DNS Zones are global resources
}

variable "vnet_link_registration_enabled" {
  description = "Enable auto-registration of VM DNS records in the Private DNS Zone"
  type        = bool
  default     = false
}

variable "ttl" {
  description = "Time to Live (TTL) in seconds for the DNS A record"
  type        = number
  default     = 300
  validation {
    condition     = var.ttl >= 10 && var.ttl <= 2147483647
    error_message = "TTL must be between 10 and 2147483647 seconds."
  }
}

variable "tags" {
  description = "Tags to apply to the DNS resources (inherits from service resource tags)"
  type        = map(string)
  default     = {}
}
