# ===================================================================
# Azure Container Registry Module - Main Resources
# ===================================================================
# This module creates an Azure Container Registry with configurable
# SKU, networking, and security settings
# ===================================================================

# -------------------------------------------------------------------
# Azure Container Registry
# -------------------------------------------------------------------
# Creates a container registry for storing and managing container images
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  # Admin user access (disabled by default for security)
  admin_enabled = var.admin_enabled

  # Geo-replication (only available for Premium SKU)
  dynamic "georeplications" {
    for_each = var.sku == "Premium" ? var.georeplications : []
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = var.tags
    }
  }

  # Network rules (only available for Premium SKU and when not using Private Endpoints exclusively)
  # When using Private Endpoints, network rules are typically not needed
  # Note: In provider 4.0, network_rule_set is an attribute (list of objects), not a block
  network_rule_set = var.sku == "Premium" && var.network_rule_set_enabled && !var.enable_private_endpoint ? [{
    default_action = var.network_rule_default_action
    ip_rule = [
      for ip in var.allowed_ip_ranges : {
        action   = "Allow"
        ip_range = ip
      }
    ]
  }] : [{
    default_action = "Allow"
    ip_rule        = []
  }]

  # Public network access (can be disabled for Premium SKU with Private Link)
  public_network_access_enabled = var.public_network_access_enabled

  # Data endpoint (creates dedicated data endpoints)
  data_endpoint_enabled = var.data_endpoint_enabled

  # Encryption settings (Premium SKU only)
  dynamic "encryption" {
    for_each = var.sku == "Premium" && var.encryption_enabled ? [1] : []
    content {
      key_vault_key_id   = var.key_vault_key_id
      identity_client_id = var.encryption_identity_client_id
    }
  }

  # Identity configuration (for encryption or other Azure integrations)
  dynamic "identity" {
    for_each = var.identity_type != null ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = var.identity_type == "UserAssigned" ? var.identity_ids : null
    }
  }

  # Retention policy for untagged manifests (Premium SKU only) - now a direct attribute
  retention_policy_in_days = var.sku == "Premium" && var.retention_policy_enabled ? var.retention_policy_days : null

  # Trust policy (Premium SKU only) - now a direct attribute
  trust_policy_enabled = var.sku == "Premium" && var.trust_policy_enabled ? true : false

  # Zone redundancy (Premium SKU only)
  zone_redundancy_enabled = var.sku == "Premium" ? var.zone_redundancy_enabled : false

  tags = var.tags
}

# -------------------------------------------------------------------
# Private Endpoint (Premium SKU only)
# -------------------------------------------------------------------
# Creates a Private Endpoint for secure, private access to the ACR
# DNS registration is handled separately by private-dns-* modules
resource "azurerm_private_endpoint" "acr" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pe-${var.acr_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-${var.acr_name}"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  lifecycle {
    precondition {
      condition     = !var.enable_private_endpoint || var.pe_subnet_id != null
      error_message = "pe_subnet_id must be provided when enable_private_endpoint is true."
    }
  }

  tags = var.tags
}
