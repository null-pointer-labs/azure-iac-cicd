# ===================================================================
# __ENV_NAME__ Environment - Terraform Variables
# ===================================================================
# Configuration values for the __ENV_NAME__ environment
# IMPORTANT: Update these values according to your requirements
# ===================================================================

# Project Configuration
project_name = "__PROJECT_NAME__"
environment  = "__ENV_NAME__"
location     = "Southeast Asia"

# ===================================================================
# Cross-Subscription Configuration
# ===================================================================
# IMPORTANT: Replace these placeholders with your actual subscription and tenant IDs
workload_subscription_id = "TODO-YOUR-WORKLOAD-SUBSCRIPTION-ID" # Subscription where resources deploy
tenant_id                = "TODO-YOUR-TENANT-ID"                 # Azure AD tenant ID

# Network Configuration
vnet_address_space            = ["172.16.200.0/22"]
app_subnet_address_prefixes   = ["172.16.200.0/26"]
data_subnet_address_prefixes  = ["172.16.200.64/26"]

# Resource Tags
# Apply consistent tags for resource management and cost tracking
tags = {
  Environment = "__ENV_NAME_UPPER__"
  Project     = "__PROJECT_NAME__"
  ManagedBy   = "Terraform"
  CreatedDate = "__DATE__"
}
