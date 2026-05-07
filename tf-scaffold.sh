#!/bin/bash
# ===================================================================
# Terraform Environment Scaffolder
# ===================================================================
# Interactively scaffolds a new Terraform environment by reading
# physical template files and performing substitutions.
# ===================================================================

set -e

# Color codes for terminal output
readonly CYAN='\033[0;36m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly BLUE='\033[0;34m'

# Paths
readonly TEMPLATES_DIR="templates"
readonly BASE_TEMPLATES="${TEMPLATES_DIR}/base"
readonly MODULE_TEMPLATES="${TEMPLATES_DIR}/modules"

# Available modules to select
declare -a MODULES=(
  "azure-acr"
  "azure-aks"
  "azure-cosmosdb"
  "azure-keyvault"
  "azure-redis"
  "azure-vm"
)

# Global variables (populated during script execution)
declare -a SELECTED_MODULES=()
declare PROJECT_NAME=""
declare ENV_NAME=""
declare ENV_NAME_UPPER=""
declare CURRENT_DATE=""
declare USE_EXISTING_PRIVATE_DNS="false"
declare DNS_SUBSCRIPTION_ID=""
declare DNS_ZONE_RG=""

# Environment variables from .env file (if exists)
declare WORKLOAD_SUBSCRIPTION_ID=""
declare TENANT_ID=""
declare LOCATION=""
declare BACKEND_SUBSCRIPTION_ID=""
declare BACKEND_RESOURCE_GROUP=""
declare BACKEND_STORAGE_ACCOUNT=""
declare BACKEND_CONTAINER=""

# ===================================================================
# Load .env file
# ===================================================================
load_env_file() {
  local env_file=".env"
  
  if [ -f "$env_file" ]; then
    echo -e "${GREEN}✓${NC} Found .env file - loading default values..."
    echo ""
    
    # Source the .env file
    set -a  # Export all variables
    source "$env_file"
    set +a  # Stop exporting
    
    # Show loaded values
    if [ -n "$WORKLOAD_SUBSCRIPTION_ID" ]; then
      echo -e "  ${CYAN}•${NC} Workload Subscription: ${WORKLOAD_SUBSCRIPTION_ID:0:8}..."
    fi
    if [ -n "$TENANT_ID" ]; then
      echo -e "  ${CYAN}•${NC} Tenant ID: ${TENANT_ID:0:8}..."
    fi
    if [ -n "$LOCATION" ]; then
      echo -e "  ${CYAN}•${NC} Location: $LOCATION"
    fi
    if [ -n "$BACKEND_SUBSCRIPTION_ID" ]; then
      echo -e "  ${CYAN}•${NC} Backend Subscription: ${BACKEND_SUBSCRIPTION_ID:0:8}..."
    fi
    if [ -n "$DNS_SUBSCRIPTION_ID" ]; then
      echo -e "  ${CYAN}•${NC} DNS Subscription: ${DNS_SUBSCRIPTION_ID:0:8}..."
    fi
    
    echo ""
  else
    echo -e "${YELLOW}ℹ${NC} No .env file found - you'll need to enter values manually"
    echo -e "${YELLOW}ℹ${NC} Create .env from .env.example to save time on future runs"
    echo ""
  fi
}

# ===================================================================
# UI Functions
# ===================================================================

# Numbered list module selector
show_module_selector() {
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  Terraform Environment Scaffolder${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BOLD}Available modules:${NC}"
  echo ""
  
  # Print numbered list of modules
  for i in "${!MODULES[@]}"; do
    local num=$((i + 1))
    echo -e "  ${GREEN}${num}.${NC} ${MODULES[$i]}"
  done
  
  echo ""
  echo -e "Enter module numbers separated by spaces (e.g., ${GREEN}1 3 5${NC}), or ${GREEN}all${NC} to select everything:"
  read -r selection
  
  # Handle "all" selection
  if [ "$selection" = "all" ]; then
    SELECTED_MODULES=("${MODULES[@]}")
    return
  fi
  
  # Parse space-separated numbers
  SELECTED_MODULES=()
  local -a selected_indices=()
  
  for num in $selection; do
    # Validate that input is a number
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}Error: '$num' is not a valid number${NC}"
      exit 1
    fi
    
    # Convert to 0-based index
    local idx=$((num - 1))
    
    # Validate range
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#MODULES[@]}" ]; then
      echo -e "${RED}Error: Number '$num' is out of range (valid: 1-${#MODULES[@]})${NC}"
      exit 1
    fi
    
    # Add to selected indices (avoid duplicates)
    if [[ ! " ${selected_indices[@]} " =~ " ${idx} " ]]; then
      selected_indices+=("$idx")
      SELECTED_MODULES+=("${MODULES[$idx]}")
    fi
  done
  
  # Validate at least one module is selected
  if [ "${#SELECTED_MODULES[@]}" -eq 0 ]; then
    echo -e "${RED}Error: No modules selected. Please select at least one module.${NC}"
    exit 1
  fi
}

# ===================================================================
# DNS Configuration - Automatically determined from .env
# ===================================================================
# No manual prompt needed - DNS mode is automatically detected:
#   - If .env has DNS_SUBSCRIPTION_ID and DNS_ZONE_RG -> Cross-Subscription mode
#   - Otherwise -> Standalone mode
# ===================================================================

# ===================================================================
# Template Processing Functions
# ===================================================================

# Perform substitutions on content
substitute_placeholders() {
  local content="$1"
  
  # Replace all placeholders
  content=$(echo "$content" | sed -e "s/__PROJECT_NAME__/${PROJECT_NAME}/g")
  content=$(echo "$content" | sed -e "s/__ENV_NAME__/${ENV_NAME}/g")
  content=$(echo "$content" | sed -e "s/__ENV_NAME_UPPER__/${ENV_NAME_UPPER}/g")
  content=$(echo "$content" | sed -e "s/__DATE__/${CURRENT_DATE}/g")
  
  # Replace environment-specific values from .env (if loaded)
  if [ -n "$WORKLOAD_SUBSCRIPTION_ID" ]; then
    content=$(echo "$content" | sed -e "s/TODO-YOUR-WORKLOAD-SUBSCRIPTION-ID/${WORKLOAD_SUBSCRIPTION_ID}/g")
    content=$(echo "$content" | sed -e "s/TODO: YOUR-WORKLOAD-SUBSCRIPTION-ID/${WORKLOAD_SUBSCRIPTION_ID}/g")
  fi
  
  if [ -n "$TENANT_ID" ]; then
    content=$(echo "$content" | sed -e "s/TODO-YOUR-TENANT-ID/${TENANT_ID}/g")
    content=$(echo "$content" | sed -e "s/TODO: <TENANT_ID>/${TENANT_ID}/g")
  fi
  
  if [ -n "$LOCATION" ]; then
    content=$(echo "$content" | sed -e "s/Southeast Asia/${LOCATION}/g")
  fi
  
  if [ -n "$BACKEND_SUBSCRIPTION_ID" ]; then
    content=$(echo "$content" | sed -e "s/TODO: <MANAGEMENT_SUBSCRIPTION_ID>/${BACKEND_SUBSCRIPTION_ID}/g")
  fi
  
  if [ -n "$BACKEND_RESOURCE_GROUP" ]; then
    content=$(echo "$content" | sed -e "s/TODO: rg-tfstate-mgmt/${BACKEND_RESOURCE_GROUP}/g")
  fi
  
  if [ -n "$BACKEND_STORAGE_ACCOUNT" ]; then
    content=$(echo "$content" | sed -e "s/TODO: sttfstatemgmt001/${BACKEND_STORAGE_ACCOUNT}/g")
  fi
  
  if [ -n "$BACKEND_CONTAINER" ]; then
    # Only replace if user has a custom container name
    content=$(echo "$content" | sed -e "s/container_name       = \"tfstate\"/container_name       = \"${BACKEND_CONTAINER}\"/g")
  fi
  
  echo "$content"
}

# Check if module is in selected list
is_module_selected() {
  local module_name="$1"
  for selected in "${SELECTED_MODULES[@]}"; do
    if [ "$selected" = "$module_name" ]; then
      return 0
    fi
  done
  return 1
}

# Add Private DNS module calls based on selected modules
add_private_dns_modules() {
  local has_pe_modules=false
  
  # Check if any module with Private Endpoint support is selected
  for module in "${SELECTED_MODULES[@]}"; do
    case "$module" in
      azure-acr|azure-keyvault|azure-cosmosdb)
        has_pe_modules=true
        break
        ;;
    esac
  done
  
  if [ "$has_pe_modules" = false ]; then
    return
  fi
  
  echo ""
  echo "# ==================================================================="
  echo "# Private DNS Configuration for Private Endpoints"
  echo "# ==================================================================="
  echo "# Conditional DNS module calls based on use_existing_private_dns flag"
  echo "# ==================================================================="
  echo ""
  
  # Generate DNS module calls for each service with Private Endpoint
  if is_module_selected "azure-acr"; then
    echo "# Azure Container Registry - Private DNS"
    if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
      cat << 'EOF'
module "acr_dns_existing" {
  count  = var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.container_registry.pe_private_ip
  dns_zone_name       = "privatelink.azurecr.io"
  record_name         = var.acr_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

EOF
    else
      cat << 'EOF'
module "acr_dns_standalone" {
  count  = !var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.container_registry.pe_private_ip
  dns_zone_name      = "privatelink.azurecr.io"
  record_name        = var.acr_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

EOF
    fi
  fi
  
  if is_module_selected "azure-keyvault"; then
    echo "# Azure Key Vault - Private DNS"
    if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
      cat << 'EOF'
module "keyvault_dns_existing" {
  count  = var.use_existing_private_dns && var.keyvault_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.key_vault.pe_private_ip
  dns_zone_name       = "privatelink.vaultcore.azure.net"
  record_name         = var.keyvault_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

EOF
    else
      cat << 'EOF'
module "keyvault_dns_standalone" {
  count  = !var.use_existing_private_dns && var.keyvault_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.key_vault.pe_private_ip
  dns_zone_name      = "privatelink.vaultcore.azure.net"
  record_name        = var.keyvault_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

EOF
    fi
  fi
  
  if is_module_selected "azure-cosmosdb"; then
    echo "# Azure Cosmos DB - Private DNS"
    if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
      cat << 'EOF'
module "cosmosdb_dns_existing" {
  count  = var.use_existing_private_dns && var.cosmosdb_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.cosmos_db.pe_private_ip
  dns_zone_name       = "privatelink.mongo.cosmos.azure.com"  # Adjust based on API type
  record_name         = var.cosmosdb_account_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

EOF
    else
      cat << 'EOF'
module "cosmosdb_dns_standalone" {
  count  = !var.use_existing_private_dns && var.cosmosdb_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.cosmos_db.pe_private_ip
  dns_zone_name      = "privatelink.mongo.cosmos.azure.com"  # Adjust based on API type
  record_name        = var.cosmosdb_account_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

EOF
    fi
  fi
}
# Add Private DNS variable declarations
add_private_dns_variables() {
  local has_pe_modules=false
  
  # Check if any module with Private Endpoint support is selected
  for module in "${SELECTED_MODULES[@]}"; do
    case "$module" in
      azure-acr|azure-keyvault|azure-cosmosdb)
        has_pe_modules=true
        break
        ;;
    esac
  done
  
  if [ "$has_pe_modules" = false ]; then
    return
  fi
  
  echo ""
  echo "# ==================================================================="
  echo "# Private DNS Variables"
  echo "# ==================================================================="
  echo ""
  
  cat << 'EOF'
variable "use_existing_private_dns" {
  description = "Use existing Private DNS Zones in separate subscription (true) or create standalone zones (false)"
  type        = bool
  default     = false
}

variable "dns_zone_rg" {
  description = "Resource Group for DNS Zones (in DNS subscription if cross-sub, or workload subscription if standalone)"
  type        = string
}

EOF

  if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
    cat << 'EOF'
variable "dns_subscription_id" {
  description = "Subscription ID where Private DNS Zones exist (required when use_existing_private_dns = true)"
  type        = string
  default     = ""
}

EOF
  fi
}

# Add Private DNS terraform.tfvars values
add_private_dns_tfvars() {
  local has_pe_modules=false
  
  # Check if any module with Private Endpoint support is selected
  for module in "${SELECTED_MODULES[@]}"; do
    case "$module" in
      azure-acr|azure-keyvault|azure-cosmosdb)
        has_pe_modules=true
        break
        ;;
    esac
  done
  
  if [ "$has_pe_modules" = false ]; then
    return
  fi
  
  echo ""
  echo "# ==================================================================="
  echo "# Private DNS Configuration"
  echo "# ==================================================================="
  
  if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
    echo "# Cross-subscription DNS mode: Uses existing Private DNS Zones in DNS subscription"
    echo "use_existing_private_dns = true"
    echo "dns_subscription_id      = \"${DNS_SUBSCRIPTION_ID}\""
    echo "dns_zone_rg              = \"${DNS_ZONE_RG}\""
    echo ""
    echo "# Prerequisites for cross-subscription DNS:"
    echo "# • Private DNS Zones exist in DNS subscription"
    echo "# • VNet Links configured to hub VNet"
    echo "# • VNet peering established between workload and hub VNets"
    echo "# • RBAC: 'Private DNS Zone Contributor' role in DNS subscription"
  else
    echo "# Standalone DNS mode: Creates new Private DNS Zones in workload subscription"
    echo "use_existing_private_dns = false"
    echo "dns_zone_rg              = \"${DNS_ZONE_RG}\""
  fi
  
  echo ""
}
# Generate main.tf by assembling base + selected modules
generate_main_tf() {
  local output_file="$1"
  
  # Start with base infrastructure
  cat "${BASE_TEMPLATES}/main.tf" > "$output_file"
  
  # Append module-specific infrastructure blocks conditionally
  local infra_dir="${TEMPLATES_DIR}/infrastructure"
  if [ -d "$infra_dir" ]; then
    # Include AKS subnet only if azure-aks module is selected
    if is_module_selected "azure-aks"; then
      local aks_infra="${infra_dir}/azure-aks-subnet.tf"
      if [ -f "$aks_infra" ]; then
        echo "" >> "$output_file"
        cat "$aks_infra" >> "$output_file"
      fi
    fi
    
    # Add similar conditional blocks for other module-specific infrastructure here
    # Example:
    # if is_module_selected "azure-other-module"; then
    #   local other_infra="${infra_dir}/azure-other-module-subnet.tf"
    #   if [ -f "$other_infra" ]; then
    #     echo "" >> "$output_file"
    #     cat "$other_infra" >> "$output_file"
    #   fi
    # fi
  fi
  
  # Append selected module blocks
  for module in "${SELECTED_MODULES[@]}"; do
    local module_template="${MODULE_TEMPLATES}/${module}/main.tf"
    if [ -f "$module_template" ]; then
      cat "$module_template" >> "$output_file"
    else
      echo -e "${YELLOW}Warning: Template not found: ${module_template}${NC}" >&2
    fi
  done
  
  # Add Private DNS module calls for services with Private Endpoints
  add_private_dns_modules >> "$output_file"
  
  # Perform substitutions
  local content=$(cat "$output_file")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate terraform.tfvars by assembling base + selected modules
generate_terraform_tfvars() {
  local output_file="$1"
  
  # Start with base configuration
  cat "${BASE_TEMPLATES}/terraform.tfvars" > "$output_file"
  
  # Append module-specific infrastructure tfvars conditionally
  local infra_dir="${TEMPLATES_DIR}/infrastructure"
  if [ -d "$infra_dir" ]; then
    # Include AKS subnet tfvars only if azure-aks module is selected
    if is_module_selected "azure-aks"; then
      local aks_tfvars="${infra_dir}/azure-aks-subnet.tfvars"
      if [ -f "$aks_tfvars" ]; then
        cat "$aks_tfvars" >> "$output_file"
      fi
    fi
    
    # Add similar conditional blocks for other module-specific infrastructure here
  fi
  
  # Append selected module configurations
  for module in "${SELECTED_MODULES[@]}"; do
    local module_tfvars="${MODULE_TEMPLATES}/${module}/terraform.tfvars"
    if [ -f "$module_tfvars" ]; then
      cat "$module_tfvars" >> "$output_file"
    else
      echo -e "${YELLOW}Warning: Template not found: ${module_tfvars}${NC}" >&2
    fi
  done
  
  # Add Private DNS configuration
  add_private_dns_tfvars >> "$output_file"
  
  # Perform substitutions
  local content=$(cat "$output_file")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate variables.tf by assembling base + selected module variables
generate_variables_tf() {
  local output_file="$1"
  
  # Start with base variables
  cat "${BASE_TEMPLATES}/variables.tf" > "$output_file"
  
  # Append module-specific infrastructure variables conditionally
  local infra_dir="${TEMPLATES_DIR}/infrastructure"
  if [ -d "$infra_dir" ]; then
    # Include AKS subnet variables only if azure-aks module is selected
    if is_module_selected "azure-aks"; then
      local aks_vars="${infra_dir}/azure-aks-subnet.variables.tf"
      if [ -f "$aks_vars" ]; then
        cat "$aks_vars" >> "$output_file"
      fi
    fi
    
    # Add similar conditional blocks for other module-specific infrastructure here
  fi
  
  # Append selected module variable definitions
  for module in "${SELECTED_MODULES[@]}"; do
    local module_vars="${MODULE_TEMPLATES}/${module}/variables.tf"
    if [ -f "$module_vars" ]; then
      cat "$module_vars" >> "$output_file"
    fi
  done
  
  # Add Private DNS variables
  add_private_dns_variables >> "$output_file"
  
  # Perform substitutions
  local content=$(cat "$output_file")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate backend.tf from template
generate_backend_tf() {
  local output_file="$1"
  
  if [ ! -f "${BASE_TEMPLATES}/backend.tf" ]; then
    return
  fi
  
  local content=$(cat "${BASE_TEMPLATES}/backend.tf")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate backend.hcl from template
generate_backend_hcl() {
  local output_file="$1"
  
  if [ ! -f "${BASE_TEMPLATES}/backend.hcl" ]; then
    return
  fi
  
  local content=$(cat "${BASE_TEMPLATES}/backend.hcl")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate backend.hcl.example from backend.hcl
generate_backend_hcl_example() {
  local output_file="$1"
  
  if [ ! -f "${BASE_TEMPLATES}/backend.hcl" ]; then
    return
  fi
  
  # Use the same template, it already has TODO placeholders
  local content=$(cat "${BASE_TEMPLATES}/backend.hcl")
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# Generate providers.tf from template
generate_providers_tf() {
  local output_file="$1"
  
  if [ ! -f "${BASE_TEMPLATES}/providers.tf" ]; then
    return
  fi
  
  local content=$(cat "${BASE_TEMPLATES}/providers.tf")
  
  # Add cross-subscription DNS provider if needed
  if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
    content="${content}

# ===================================================================
# Provider: DNS Subscription (Cross-Subscription DNS Management)
# ===================================================================
# Used when use_existing_private_dns = true
# Accesses existing Private DNS Zones in a separate subscription

provider \"azurerm\" {
  alias = \"dns_sub\"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.dns_subscription_id
  tenant_id       = var.tenant_id
}
"
  fi
  
  content=$(substitute_placeholders "$content")
  echo "$content" > "$output_file"
}

# ===================================================================
# Diff and Summary Functions
# ===================================================================

# Print diff summary of substitutions
print_diff_summary() {
  echo ""
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  Generation Summary${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BOLD}Source:${NC}       ${TEMPLATES_DIR}/"
  echo -e "${BOLD}Target:${NC}       projects/${PROJECT_NAME}-${ENV_NAME}/"
  echo ""
  echo -e "${BOLD}Substitutions applied:${NC}"
  echo -e "  • ${YELLOW}__PROJECT_NAME__${NC} → ${GREEN}${PROJECT_NAME}${NC}"
  echo -e "  • ${YELLOW}__ENV_NAME__${NC} → ${GREEN}${ENV_NAME}${NC}"
  echo -e "  • ${YELLOW}__ENV_NAME_UPPER__${NC} → ${GREEN}${ENV_NAME_UPPER}${NC}"
  echo -e "  • ${YELLOW}__DATE__${NC} → ${GREEN}${CURRENT_DATE}${NC}"
  echo ""
  echo -e "${BOLD}Modules included:${NC}"
  for module in "${SELECTED_MODULES[@]}"; do
    echo -e "  ${GREEN}✓${NC} ${module}"
  done
  
  # List modules that were filtered out
  echo ""
  echo -e "${BOLD}Modules excluded:${NC}"
  for module in "${MODULES[@]}"; do
    if ! is_module_selected "$module"; then
      echo -e "  ${RED}✗${NC} ${module}"
    fi
  done
  
  # Show Private DNS configuration if applicable
  local has_pe_modules=false
  for module in "${SELECTED_MODULES[@]}"; do
    case "$module" in
      azure-acr|azure-keyvault|azure-cosmosdb)
        has_pe_modules=true
        break
        ;;
    esac
  done
  
  if [ "$has_pe_modules" = true ]; then
    echo ""
    echo -e "${BOLD}Private DNS Configuration:${NC}"
    if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
      echo -e "  ${GREEN}✓${NC} Mode: Cross-Subscription (existing DNS zones)"
      echo -e "  ${GREEN}✓${NC} DNS Subscription ID: ${DNS_SUBSCRIPTION_ID}"
      echo -e "  ${GREEN}✓${NC} DNS Resource Group: ${DNS_ZONE_RG}"
    else
      echo -e "  ${GREEN}✓${NC} Mode: Standalone (creates new DNS zones)"
      echo -e "  ${GREEN}✓${NC} DNS Resource Group: ${DNS_ZONE_RG}"
    fi
  fi
  
  echo ""
}

# ===================================================================
# Main Script
# ===================================================================

main() {
  echo -e "${BOLD}${CYAN}Terraform Environment Scaffolder${NC}"
  echo ""
  
  # Load .env file if it exists
  load_env_file
  
  # Step 1: Get project name
  echo -e "${BOLD}Project name${NC} (e.g., cics, komopro):"
  read -r PROJECT_NAME
  
  if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name cannot be empty${NC}"
    exit 1
  fi
  
  if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}Error: Project name must be alphanumeric with hyphens only${NC}"
    exit 1
  fi
  
  echo ""
  
  # Step 2: Get environment name
  echo -e "${BOLD}Environment name${NC} (e.g., dev, uat, prod):"
  read -r ENV_NAME
  
  if [ -z "$ENV_NAME" ]; then
    echo -e "${RED}Error: Environment name cannot be empty${NC}"
    exit 1
  fi
  
  if ! [[ "$ENV_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}Error: Environment name must be alphanumeric with hyphens only${NC}"
    exit 1
  fi
  
  # Set derived variables
  ENV_NAME_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
  CURRENT_DATE=$(date +%Y-%m-%d)
  
  echo ""
  
  # Step 3: Module selection
  show_module_selector
  clear
  
  echo -e "${GREEN}✓${NC} Selected modules:"
  for mod in "${SELECTED_MODULES[@]}"; do
    echo "  • $mod"
  done
  echo ""
  
  # Step 4: Private DNS configuration (if any PE-enabled modules selected)
  local needs_dns=false
  for module in "${SELECTED_MODULES[@]}"; do
    case "$module" in
      azure-acr|azure-keyvault|azure-cosmosdb)
        needs_dns=true
        break
        ;;
    esac
  done
  
  if [ "$needs_dns" = true ]; then
    # Automatically detect DNS mode based on .env values
    if [ -n "$DNS_SUBSCRIPTION_ID" ] && [ -n "$DNS_ZONE_RG" ]; then
      # Cross-subscription mode: .env has both DNS values
      USE_EXISTING_PRIVATE_DNS="true"
      echo -e "${GREEN}✓${NC} Detected Cross-Subscription DNS mode from .env"
      echo "  • DNS Subscription: ${DNS_SUBSCRIPTION_ID:0:8}..."
      echo "  • DNS Resource Group: ${DNS_ZONE_RG}"
    else
      # Standalone mode: No DNS values in .env
      USE_EXISTING_PRIVATE_DNS="false"
      DNS_ZONE_RG="rg-${PROJECT_NAME}-${ENV_NAME}-dns"
      echo -e "${GREEN}✓${NC} Using Standalone DNS mode (no DNS config in .env)"
      echo "  • DNS Resource Group: ${DNS_ZONE_RG}"
    fi
    echo ""
  fi
  
  local output_dir="projects/${PROJECT_NAME}-${ENV_NAME}"
  
  # Step 5: Check if directory exists
  if [ -d "$output_dir" ]; then
    echo ""
    echo -e "${YELLOW}Warning: Directory '${output_dir}' already exists${NC}"
    echo -n "Overwrite? (y/N): "
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      echo -e "${RED}Aborted.${NC}"
      exit 0
    fi
  fi
  
  # Step 6: Create directory and generate files
  echo ""
  echo -e "${CYAN}Generating configuration from templates...${NC}"
  
  mkdir -p "$output_dir"
  
  # Generate main.tf
  echo -e "  ${CYAN}→${NC} Assembling main.tf..."
  generate_main_tf "${output_dir}/main.tf"
  
  # Generate variables.tf
  echo -e "  ${CYAN}→${NC} Assembling variables.tf..."
  generate_variables_tf "${output_dir}/variables.tf"
  
  # Generate terraform.tfvars
  echo -e "  ${CYAN}→${NC} Assembling terraform.tfvars..."
  generate_terraform_tfvars "${output_dir}/terraform.tfvars"
  
  # Generate backend.tf
  if [ -f "${BASE_TEMPLATES}/backend.tf" ]; then
    echo -e "  ${CYAN}→${NC} Generating backend.tf..."
    generate_backend_tf "${output_dir}/backend.tf"
  fi
  
  # Generate backend.hcl
  if [ -f "${BASE_TEMPLATES}/backend.hcl" ]; then
    echo -e "  ${CYAN}→${NC} Generating backend.hcl..."
    generate_backend_hcl "${output_dir}/backend.hcl"
  fi
  
  # Generate backend.hcl.example
  if [ -f "${BASE_TEMPLATES}/backend.hcl" ]; then
    echo -e "  ${CYAN}→${NC} Generating backend.hcl.example..."
    generate_backend_hcl_example "${output_dir}/backend.hcl.example"
  fi
  
  # Generate providers.tf
  if [ -f "${BASE_TEMPLATES}/providers.tf" ]; then
    echo -e "  ${CYAN}→${NC} Generating providers.tf..."
    generate_providers_tf "${output_dir}/providers.tf"
  fi
  
  # Print summary
  print_diff_summary
  
  # Step 7: Success summary
  echo -e "${GREEN}${BOLD}✓ Environment scaffolded successfully!${NC}"
  echo ""
  echo -e "${BOLD}Created files in ${output_dir}/${NC}"
  for file in "$output_dir"/*; do
    if [ -f "$file" ]; then
      local filename=$(basename "$file")
      local filesize=$(wc -l < "$file")
      echo -e "  ${GREEN}✓${NC} ${filename} (${filesize} lines)"
    fi
  done
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo "  1. Review generated files in ${output_dir}/"
  echo "  2. Update TODO placeholders in terraform.tfvars"
  echo "  3. Update backend.hcl with your Azure backend configuration"
  echo "  4. Run: cd ${output_dir} && terraform init -backend-config=backend.hcl"
  echo "  5. Run: terraform plan"
  echo "  6. Run: terraform apply"
  echo ""
}

# Run main function
main
