
# -------------------------------------------------------------------
# Azure Container Registry
# -------------------------------------------------------------------
# Deploy container registry using the azure-acr module with Private Endpoint
module "container_registry" {
  source = "../../modules/azure-acr"

  acr_name            = var.acr_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = var.acr_sku

  # Private Endpoint configuration
  enable_private_endpoint = var.acr_enable_private_endpoint
  pe_subnet_id            = azurerm_subnet.app.id
  pe_resource_group_name  = azurerm_resource_group.network.name
  vnet_id                 = azurerm_virtual_network.main.id

  # Data endpoint
  data_endpoint_enabled = var.acr_data_endpoint_enabled

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "container-registry"
    }
  )
}
