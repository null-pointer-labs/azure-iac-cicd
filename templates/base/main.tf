# ===================================================================
# __ENV_NAME__ Environment - Main Configuration
# ===================================================================
# This configuration deploys the __ENV_NAME__ environment infrastructure
# including VNet, and Subnets
# Resource Groups are conditionally created based on selected modules
# ===================================================================

# -------------------------------------------------------------------
# Virtual Network
# -------------------------------------------------------------------
# Creates a VNet for the __ENV_NAME__ environment in the Network RG
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}-apse-001"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# -------------------------------------------------------------------
# Subnets
# -------------------------------------------------------------------
# Private Endpoint Subnet - for PaaS services (ACR, Storage, etc.)
resource "azurerm_subnet" "pe" {
  name                 = "snet-${var.project_name}-${var.environment}-pe"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.pe_subnet_address_prefixes
}
