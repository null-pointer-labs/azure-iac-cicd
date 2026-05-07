# ===================================================================
# __ENV_NAME__ Environment - Main Configuration
# ===================================================================
# This configuration deploys the __ENV_NAME__ environment infrastructure
# including Resource Group, VNet, and Subnets
# ===================================================================

# -------------------------------------------------------------------
# Resource Group
# -------------------------------------------------------------------
# Creates a dedicated resource group for the __ENV_NAME__ environment
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = var.tags
}

# -------------------------------------------------------------------
# Virtual Network
# -------------------------------------------------------------------
# Creates a VNet for the __ENV_NAME__ environment
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# -------------------------------------------------------------------
# Subnets
# -------------------------------------------------------------------
# Private Endpoint Subnet - for PaaS services (ACR, Storage, etc.)
resource "azurerm_subnet" "pe" {
  name                 = "snet-${var.project_name}-${var.environment}-pe"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.pe_subnet_address_prefixes
}
