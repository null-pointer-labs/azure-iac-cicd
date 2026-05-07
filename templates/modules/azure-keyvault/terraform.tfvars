
# ===================================================================
# Azure Key Vault Configuration
# ===================================================================
# Standard SKU with Private Endpoint for secure secret management
keyvault_name                    = "kv-__PROJECT_NAME__-__ENV_NAME__" # Must be globally unique, 3-24 characters
keyvault_sku_name                = "standard"                         # Use 'standard' for cost optimization (premium adds HSM support)
keyvault_enable_private_endpoint = true                               # Enable Private Endpoint for secure access
keyvault_purge_protection        = false                              # Set to true for production to prevent accidental permanent deletion
keyvault_soft_delete_days        = 90                                 # Retain deleted items for 90 days (max retention)
