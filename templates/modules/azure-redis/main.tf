
# -------------------------------------------------------------------
# Azure Redis Cache
# -------------------------------------------------------------------
# Deploy Redis Cache using the azure-redis module
module "redis_cache" {
  source = "../../modules/azure-redis"

  redis_name          = var.redis_name
  location            = azurerm_resource_group.data.location
  resource_group_name = azurerm_resource_group.data.name
  sku_name            = var.redis_sku_name
  family              = var.redis_family
  capacity            = var.redis_capacity

  # Private Endpoint configuration (only for Standard/Premium SKUs)
  enable_private_endpoint = var.redis_enable_private_endpoint
  pe_subnet_id            = var.redis_enable_private_endpoint ? azurerm_subnet.data.id : null
  pe_resource_group_name  = var.redis_enable_private_endpoint ? azurerm_resource_group.network.name : null
  vnet_id                 = var.redis_enable_private_endpoint ? azurerm_virtual_network.main.id : null

  # Security settings
  public_network_access_enabled = !var.redis_enable_private_endpoint

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "redis-cache"
    }
  )
}
