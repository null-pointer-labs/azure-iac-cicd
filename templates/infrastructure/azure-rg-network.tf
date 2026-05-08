
# -------------------------------------------------------------------
# Resource Group: Network
# -------------------------------------------------------------------
# Network resource group for VNet, Subnets, and Private Endpoints
resource "azurerm_resource_group" "network" {
  name     = "rg-${var.project_name}-network-${var.environment}-001"
  location = var.location

  tags = merge(
    var.tags,
    {
      Area = "network"
    }
  )
}
