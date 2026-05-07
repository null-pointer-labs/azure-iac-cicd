# ===================================================================
# Private DNS Standalone Module - Outputs
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Outputs for standalone Private DNS Zone and A record registration
# ===================================================================

output "dns_zone_id" {
  description = "Resource ID of the created Private DNS Zone"
  value       = azurerm_private_dns_zone.zone.id
}

output "dns_zone_name" {
  description = "Name of the created Private DNS Zone"
  value       = azurerm_private_dns_zone.zone.name
}

output "vnet_link_id" {
  description = "Resource ID of the VNet Link"
  value       = azurerm_private_dns_zone_virtual_network_link.vnet_link.id
}

output "dns_record_id" {
  description = "Resource ID of the DNS A record"
  value       = azurerm_private_dns_a_record.pe_record.id
}

output "dns_record_fqdn" {
  description = "Fully Qualified Domain Name of the DNS A record (e.g., myacr.privatelink.azurecr.io)"
  value       = "${var.record_name}.${var.dns_zone_name}"
}

output "private_ip_address" {
  description = "Private IP address registered in DNS (passthrough from input)"
  value       = var.private_ip_address
}
