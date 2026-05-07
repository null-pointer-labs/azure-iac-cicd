
# ===================================================================
# Azure Container Registry Configuration
# ===================================================================
# Premium SKU with Private Endpoint for secure access
acr_name                    = "acr__PROJECT_NAME____ENV_NAME__" # Must be globally unique, alphanumeric only
acr_sku                     = "Premium"                         # Premium required for Private Endpoints
acr_enable_private_endpoint = true                              # Enable Private Endpoint for secure access
acr_data_endpoint_enabled   = true                              # Enable data endpoints with tenant-reuse scope