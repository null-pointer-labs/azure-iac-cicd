# ===================================================================
# Private DNS Registration Module - Outputs
# ===================================================================
# SERVICE-AGNOSTIC UTILITY MODULE
# 
# Outputs for DNS A record registration in existing DNS zone
# ===================================================================

output "dns_record_id" {
  description = "Resource ID of the DNS A record"
  value       = azurerm_private_dns_a_record.pe_record.id
}

output "dns_record_fqdn" {
  description = "Fully Qualified Domain Name of the DNS A record (e.g., myacr.privatelink.azurecr.io)"
  value       = "${var.record_name}.${var.dns_zone_name}"
}

output "dns_zone_id" {
  description = "Resource ID of the existing Private DNS Zone"
  value       = data.azurerm_private_dns_zone.existing.id
}

output "dns_zone_name" {
  description = "Name of the existing Private DNS Zone"
  value       = data.azurerm_private_dns_zone.existing.name
}

output "private_ip_address" {
  description = "Private IP address registered in DNS (passthrough from input)"
  value       = var.private_ip_address
}
