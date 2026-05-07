# ===================================================================
# Azure Redis Cache Module - Main Resources
# ===================================================================
# This module creates an Azure Redis Cache with configurable
# SKU, networking, and security settings
# ===================================================================

# -------------------------------------------------------------------
# Azure Redis Cache
# -------------------------------------------------------------------
# Creates a Redis cache instance for caching and session management
resource "azurerm_redis_cache" "main" {
  name                = var.redis_name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name

  # Enable non-SSL port (disabled by default for security)
  non_ssl_port_enabled = var.enable_non_ssl_port

  # Minimum TLS version for security
  minimum_tls_version = var.minimum_tls_version

  # Public network access control
  public_network_access_enabled = var.public_network_access_enabled

  # Redis configuration settings
  redis_configuration {
    maxmemory_reserved              = var.maxmemory_reserved
    maxmemory_delta                 = var.maxmemory_delta
    maxmemory_policy                = var.maxmemory_policy
    maxfragmentationmemory_reserved = var.maxfragmentationmemory_reserved
    
    # RDB backup configuration (Premium SKU only)
    rdb_backup_enabled            = var.sku_name == "Premium" ? var.rdb_backup_enabled : null
    rdb_backup_frequency          = var.sku_name == "Premium" && var.rdb_backup_enabled ? var.rdb_backup_frequency : null
    rdb_backup_max_snapshot_count = var.sku_name == "Premium" && var.rdb_backup_enabled ? var.rdb_backup_max_snapshot_count : null
    rdb_storage_connection_string = var.sku_name == "Premium" && var.rdb_backup_enabled ? var.rdb_storage_connection_string : null
  }

  # Redis version
  redis_version = var.redis_version

  # Shard count (Premium SKU only, for clustering)
  shard_count = var.sku_name == "Premium" ? var.shard_count : null

  # Subnet for VNet integration (Premium SKU only)
  subnet_id = var.sku_name == "Premium" && var.subnet_id != null ? var.subnet_id : null

  # Zones for zone redundancy (Premium SKU only)
  zones = var.sku_name == "Premium" && var.zones != null ? var.zones : null

  # Identity configuration
  dynamic "identity" {
    for_each = var.identity_type != null ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = var.identity_type == "UserAssigned" ? var.identity_ids : null
    }
  }

  # Patch schedule (optional)
  dynamic "patch_schedule" {
    for_each = var.patch_schedule != null ? [var.patch_schedule] : []
    content {
      day_of_week    = patch_schedule.value.day_of_week
      start_hour_utc = patch_schedule.value.start_hour_utc
    }
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Private Endpoint (Optional)
# -------------------------------------------------------------------
# Creates a Private Endpoint for secure access to Redis Cache
resource "azurerm_private_endpoint" "redis" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pe-${var.redis_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-${var.redis_name}"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Private DNS Zone (Optional)
# -------------------------------------------------------------------
# Creates a Private DNS Zone for name resolution of the Private Endpoint
resource "azurerm_private_dns_zone" "redis" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count = var.enable_private_endpoint ? 1 : 0

  name                  = "pdnslink-${var.redis_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# DNS A Record for Private Endpoint
resource "azurerm_private_dns_a_record" "redis" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = var.redis_name
  zone_name           = azurerm_private_dns_zone.redis[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.redis[0].private_service_connection[0].private_ip_address]

  tags = var.tags
}

# -------------------------------------------------------------------
# Firewall Rules (Optional)
# -------------------------------------------------------------------
# Creates firewall rules to allow specific IP ranges
# Only applicable when public_network_access_enabled is true
resource "azurerm_redis_firewall_rule" "main" {
  for_each = var.public_network_access_enabled ? var.firewall_rules : {}

  name                = each.key
  redis_cache_name    = azurerm_redis_cache.main.name
  resource_group_name = var.resource_group_name
  start_ip            = each.value.start_ip
  end_ip              = each.value.end_ip
}
