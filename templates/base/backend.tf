# ===================================================================
# __ENV_NAME__ Environment - Backend Configuration (Partial Backend Pattern)
# ===================================================================
# This file declares an empty backend block. Actual configuration values
# are supplied at init time via: terraform init -backend-config=backend.hcl
#
# Why partial backend?
# - Backend blocks cannot reference Terraform variables
# - Allows dynamic backend configuration per environment
# - Supports cross-subscription state management
# - Enables Azure AD authentication (no storage keys)
# ===================================================================

terraform {
  backend "azurerm" {
    # Use Azure AD authentication instead of storage account keys
    # Requires: Storage Blob Data Contributor role on the state container
    use_azuread_auth = true
  }
}

# ===================================================================
# Configuration is provided via backend.hcl:
# ===================================================================
# - resource_group_name  = Resource group containing state storage (management subscription)
# - storage_account_name = Storage account name for state
# - container_name       = Container name for state files
# - key                  = Path to this environment's state file (e.g., "__ENV_NAME__/terraform.tfstate")
# - subscription_id      = Management subscription ID (where state storage lives)
# - tenant_id            = Azure AD tenant ID
#
# Initialize with: terraform init -backend-config=backend.hcl
# ===================================================================

# ===================================================================
# IMPORTANT: backend.hcl contains sensitive subscription IDs
# - DO NOT commit backend.hcl with real values to version control
# - Add backend.hcl to .gitignore
# - Provide backend.hcl.example as a template
# ===================================================================
