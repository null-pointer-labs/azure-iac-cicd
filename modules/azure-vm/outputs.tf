# ===================================================================
# Azure VM Module - Outputs
# ===================================================================
# Exports important resource attributes for use by calling modules
# ===================================================================

output "vm_ids" {
  description = "List of virtual machine IDs"
  value       = azurerm_linux_virtual_machine.main[*].id
}

output "vm_names" {
  description = "List of virtual machine names"
  value       = azurerm_linux_virtual_machine.main[*].name
}

output "private_ip_addresses" {
  description = "List of private IP addresses assigned to the VMs"
  value       = azurerm_network_interface.main[*].private_ip_address
}

output "public_ip_addresses" {
  description = "List of public IP addresses assigned to the VMs (null entries if public IP is not enabled)"
  value       = var.enable_public_ip ? azurerm_public_ip.main[*].ip_address : [for i in range(var.vm_count) : null]
}

output "network_interface_ids" {
  description = "List of network interface IDs"
  value       = azurerm_network_interface.main[*].id
}

output "data_disk_ids" {
  description = "Map of data disk IDs (key format: vm_index-disk_name_suffix)"
  value       = { for k, v in azurerm_managed_disk.data : k => v.id }
}
