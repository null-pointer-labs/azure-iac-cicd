# ===================================================================
# Private DNS Registration Module - Variables
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Purpose: Register Private Endpoint IP in an EXISTING Private DNS Zone
# Scenario: Cross-subscription DNS management
# 
# This module does NOT create:
#   - Private DNS Zone (assumes pre-existing)
#   - VNet Link (assumes pre-existing)
# 
# This module only creates:
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
  description = "Name of the EXISTING Private DNS Zone (e.g., 'privatelink.azurecr.io', 'privatelink.vaultcore.azure.net', 'privatelink.mongo.cosmos.azure.com')"
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
  description = "Resource Group name where the EXISTING Private DNS Zone resides (in DNS subscription)"
  type        = string
}

variable "dns_subscription_id" {
  description = "Subscription ID where the EXISTING Private DNS Zone resides (cross-subscription access)"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.dns_subscription_id))
    error_message = "dns_subscription_id must be a valid Azure subscription GUID."
  }
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
  description = "Tags to apply to the DNS A record (inherits from service resource tags)"
  type        = map(string)
  default     = {}
}
