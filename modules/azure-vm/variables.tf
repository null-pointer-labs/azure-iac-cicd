# ===================================================================
# Azure VM Module - Input Variables
# ===================================================================
# Defines all configurable parameters for the VM module
# ===================================================================

variable "vm_name_prefix" {
  description = "Base name prefix for virtual machines (will be suffixed with -01, -02, etc.)"
  type        = string
}

variable "vm_count" {
  description = "Number of identical VMs to deploy"
  type        = number
  default     = 1
}

variable "location" {
  description = "Azure region where the resources will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the VM will be created"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the VM's NIC will be attached"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine (e.g., Standard_B2s, Standard_D2s_v3)"
  type        = string
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for authentication"
  type        = string
  sensitive   = true
}

variable "os_disk_type" {
  description = "Storage account type for the OS disk (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Standard_LRS"
}

variable "enable_public_ip" {
  description = "Whether to create and assign a public IP address to each VM"
  type        = bool
  default     = false
}

variable "data_disks" {
  description = "List of data disks to attach to each VM"
  type = list(object({
    name_suffix          = string
    disk_size_gb         = number
    storage_account_type = string
    lun                  = number
    caching              = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
