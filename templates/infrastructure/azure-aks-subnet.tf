# AKS Subnet - for Azure Kubernetes Service nodes
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.project_name}-${var.environment}-aks"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefixes
}
