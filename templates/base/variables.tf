# ===================================================================
# __ENV_NAME__ Environment - Input Variables
# ===================================================================
# Defines all configurable parameters for the __ENV_NAME__ environment
# ===================================================================

variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., __ENV_NAME__, dev, prod)"
  type        = string
  default     = "__ENV_NAME__"
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "Southeast Asia"
}

# ===================================================================
# Cross-Subscription Configuration
# ===================================================================

variable "workload_subscription_id" {
  description = "Azure subscription ID where workload resources will be deployed"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["172.16.200.0/22"]
}

variable "app_subnet_address_prefixes" {
  description = "Address prefixes for the App subnet (ACR, KeyVault, VM)"
  type        = list(string)
  default     = ["172.16.200.0/26"]
}

variable "data_subnet_address_prefixes" {
  description = "Address prefixes for the Data subnet (CosmosDB, Redis)"
  type        = list(string)
  default     = ["172.16.200.64/26"]
}

variable "tags" {
  description = "Tags to apply to all resources in this environment"
  type        = map(string)
  default     = {}
}
