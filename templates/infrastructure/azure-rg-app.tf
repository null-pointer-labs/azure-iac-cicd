
# -------------------------------------------------------------------
# Resource Group: App
# -------------------------------------------------------------------
# Application resource group for AKS, KeyVault, VM, and ACR
resource "azurerm_resource_group" "app" {
  name     = "rg-${var.project_name}-app-${var.environment}-001"
  location = var.location

  tags = merge(
    var.tags,
    {
      Area = "app"
    }
  )
}
