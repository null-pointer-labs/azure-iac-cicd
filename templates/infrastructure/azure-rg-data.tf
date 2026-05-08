
# -------------------------------------------------------------------
# Resource Group: Data
# -------------------------------------------------------------------
# Data resource group for Cosmos DB and other data services
resource "azurerm_resource_group" "data" {
  name     = "rg-${var.project_name}-data-${var.environment}-001"
  location = var.location

  tags = merge(
    var.tags,
    {
      Area = "data"
    }
  )
}
