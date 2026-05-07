# ===================================================================
# __ENV_NAME_UPPER__ Environment - Provider Configuration
# ===================================================================
# Configures the Azure provider and version requirements
# Cross-subscription setup:
# - Backend state lives in MANAGEMENT subscription (configured in backend.hcl)
# - Resources deploy to WORKLOAD subscription (configured below)
# ===================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ===================================================================
# Azure Provider - Deploys to WORKLOAD Subscription
# ===================================================================
# This provider deploys infrastructure to the workload subscription
# State is stored in a separate management subscription
provider "azurerm" {
  features {
    # Resource Group deletion behavior
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    # Virtual Machine features
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }

  # Deploy resources to the workload subscription
  subscription_id = var.workload_subscription_id
  tenant_id       = var.tenant_id

  # Authentication is handled via:
  # - Service Principal: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
  # - Azure CLI: az login
  # - Managed Identity: When running in Azure (e.g., Azure DevOps, GitHub Actions)
}
