# ===================================================================
# Azure VM Module - Main Resources
# ===================================================================
# This module creates multiple Linux VMs with network interfaces,
# optional public IPs, and data disks in an existing subnet.
# ===================================================================

# -------------------------------------------------------------------
# Local Variables
# -------------------------------------------------------------------
locals {
  # Create a flat list of all data disk attachments across all VMs
  # Format: [{vm_index: 0, disk: {...}}, {vm_index: 0, disk: {...}}, {vm_index: 1, disk: {...}}, ...]
  data_disk_attachments = flatten([
    for vm_idx in range(var.vm_count) : [
      for disk in var.data_disks : {
        vm_index     = vm_idx
        name_suffix  = disk.name_suffix
        disk_size_gb = disk.disk_size_gb
        storage_type = disk.storage_account_type
        lun          = disk.lun
        caching      = disk.caching
        # Create unique key for each disk
        key = "${vm_idx}-${disk.name_suffix}"
      }
    ]
  ])
}

# -------------------------------------------------------------------
# Network Interface (NIC)
# -------------------------------------------------------------------
# Creates network interfaces attached to the provided subnet (one per VM)
resource "azurerm_network_interface" "main" {
  count = var.vm_count

  name                = "nic-${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    # Conditionally attach public IP if enabled
    public_ip_address_id = var.enable_public_ip ? azurerm_public_ip.main[count.index].id : null
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Public IP (Optional)
# -------------------------------------------------------------------
# Creates public IP addresses if enable_public_ip is true (one per VM)
resource "azurerm_public_ip" "main" {
  count = var.enable_public_ip ? var.vm_count : 0

  name                = "pip-${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# -------------------------------------------------------------------
# Linux Virtual Machine
# -------------------------------------------------------------------
# Creates Ubuntu 22.04 LTS VMs with SSH key authentication
resource "azurerm_linux_virtual_machine" "main" {
  count = var.vm_count

  name                = "${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  # Admin user configuration with SSH key authentication
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Network interface attachment
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]

  # OS Disk configuration
  os_disk {
    name                 = "osdisk-${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  # Ubuntu 22.04 LTS image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Managed Data Disks
# -------------------------------------------------------------------
# Creates managed data disks for each VM based on data_disks variable
resource "azurerm_managed_disk" "data" {
  for_each = { for item in local.data_disk_attachments : item.key => item }

  name                 = "disk-${var.vm_name_prefix}-${format("%02d", each.value.vm_index + 1)}-${each.value.name_suffix}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.storage_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb

  tags = var.tags
}

# -------------------------------------------------------------------
# Data Disk Attachments
# -------------------------------------------------------------------
# Attaches data disks to their respective VMs
# Note: Timeouts configured to handle Azure's concurrency limitations
resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  for_each = { for item in local.data_disk_attachments : item.key => item }

  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.main[each.value.vm_index].id
  lun                = each.value.lun
  caching            = each.value.caching

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
