
# -------------------------------------------------------------------
# Azure Virtual Machines
# -------------------------------------------------------------------
# Deploy virtual machines using the azure-vm module
module "virtual_machines" {
  source = "../../modules/azure-vm"
  
  vm_name_prefix      = "vm-__PROJECT_NAME__-__ENV_NAME__"
  vm_count            = var.vm_count
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  vm_size             = var.vm_size
  subnet_id           = azurerm_subnet.pe.id
  
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  
  tags = merge(
    var.tags,
    {
      Service = "virtual-machine"
    }
  )
}
