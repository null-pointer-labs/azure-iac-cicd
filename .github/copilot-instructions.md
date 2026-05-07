# Terraform Scaffolding - Maintaining Template and Module Consistency

## ⚠️ CRITICAL: Keep Scaffold Script in Sync

**IMPORTANT**: When modifying templates, modules, or infrastructure files, you MUST update `tf-scaffold.sh` to reflect those changes. The scaffold script dynamically assembles configurations and needs to know about:
- New modules
- New infrastructure templates
- New Private Endpoint-enabled services
- Changes to file structure or naming conventions

## Overview
This project uses a Terraform scaffolding script (`tf-scaffold.sh`) that generates environment configurations by assembling template blocks. Module-specific infrastructure (like subnets, NSGs, etc.) must be conditionally included based on selected modules.

## Pattern: Adding Conditional Infrastructure for a New Module

When a module requires dedicated infrastructure resources (subnets, route tables, NSGs, etc.) that should only be included when that module is selected, follow this pattern:

### Step 1: Create Infrastructure Templates

Create three files in `templates/infrastructure/` directory:

```
templates/infrastructure/
├── azure-{module}-{resource}.tf           # Resource definition
├── azure-{module}-{resource}.variables.tf # Variable declarations
└── azure-{module}-{resource}.tfvars       # Variable values
```

**Example for AKS subnet:**

`templates/infrastructure/azure-aks-subnet.tf`:
```hcl
# AKS Subnet - for Azure Kubernetes Service nodes
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.project_name}-${var.environment}-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefixes
}
```

`templates/infrastructure/azure-aks-subnet.variables.tf`:
```hcl

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet"
  type        = list(string)
  default     = ["10.10.3.0/24"]
}
```

`templates/infrastructure/azure-aks-subnet.tfvars`:
```hcl

aks_subnet_address_prefixes = ["10.10.3.0/24"]
```

### Step 2: Remove from Base Templates

Remove the module-specific resources from:
- `templates/base/main.tf` - Remove resource blocks
- `templates/base/variables.tf` - Remove variable declarations
- `templates/base/terraform.tfvars` - Remove variable values

### Step 3: Update Scaffolding Script

Add conditional logic to three functions in `tf-scaffold.sh`:

#### In `generate_main_tf()` function:
```bash
# After the base infrastructure, add:
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  # Include {MODULE} subnet only if {module-name} module is selected
  if is_module_selected "{module-name}"; then
    local module_infra="${infra_dir}/azure-{module}-{resource}.tf"
    if [ -f "$module_infra" ]; then
      echo "" >> "$output_file"
      cat "$module_infra" >> "$output_file"
    fi
  fi
fi
```

#### In `generate_variables_tf()` function:
```bash
# After base variables, add:
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  # Include {MODULE} variables only if {module-name} module is selected
  if is_module_selected "{module-name}"; then
    local module_vars="${infra_dir}/azure-{module}-{resource}.variables.tf"
    if [ -f "$module_vars" ]; then
      cat "$module_vars" >> "$output_file"
    fi
  fi
fi
```

#### In `generate_terraform_tfvars()` function:
```bash
# After base tfvars, add:
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  # Include {MODULE} tfvars only if {module-name} module is selected
  if is_module_selected "{module-name}"; then
    local module_tfvars="${infra_dir}/azure-{module}-{resource}.tfvars"
    if [ -f "$module_tfvars" ]; then
      cat "$module_tfvars" >> "$output_file"
    fi
  fi
fi
```

### Step 4: Test

Run the scaffolding script twice:
1. With the module selected - verify infrastructure is included
2. Without the module - verify infrastructure is excluded

## When to Use This Pattern

Use conditional infrastructure fragments when:
- ✅ A resource is ONLY needed when a specific module is deployed
- ✅ The resource name or configuration contains module-specific references
- ✅ Multiple modules would conflict if the resource was always included

Do NOT use this pattern when:
- ❌ The resource is shared across multiple modules (keep in base template)
- ❌ The resource is part of core networking (like main vnet, shared subnets)
- ❌ The resource is foundational infrastructure

## Examples

**Conditional (module-specific):**
- AKS subnet (only for azure-aks)
- Application Gateway subnet (only for azure-appgw)
- Azure Bastion subnet (only for azure-bastion)

**Always included (shared infrastructure):**
- Private Endpoint subnet (used by ACR, KeyVault, Storage, etc.)
- Virtual Network
- Resource Group
- Network Security Groups for shared subnets

## Key Points

1. **Guard condition:** Use `is_module_selected "{module-name}"` to check if module is selected
2. **Module naming:** Match the exact module name from the `MODULES` array in the script
3. **File naming:** Use descriptive names: `azure-{module}-{resource-type}.{ext}`
4. **Ordering:** Infrastructure blocks are included BEFORE module blocks
5. **Placeholders:** Use `__PROJECT_NAME__`, `__ENV_NAME__`, etc. in templates - they're substituted during generation
6. **Module templates:** Each module in `templates/modules/{module-name}/` should have:
   - `main.tf` - Module block definition
   - `variables.tf` - Variable declarations needed by the module
   - `terraform.tfvars` - Default values for module variables
7. **Variable alignment:** Ensure variable names in module templates match the actual module's input variables exactly
8. **Required base files:** The `templates/base/` directory must contain:
   - `main.tf` - Base infrastructure (Resource Group, VNet, shared subnets)
   - `variables.tf` - Base variable declarations
   - `terraform.tfvars` - Base variable values
   - `backend.tf` - Backend configuration block
   - `backend.hcl` - Backend configuration values
   - `providers.tf` - Provider configuration (azurerm features, subscription, tenant)

## Adding Private Endpoint DNS Support for New Services

When adding a new Azure service that supports Private Endpoints:

### Step 1: Update `add_private_dns_modules()` Function

Add a new conditional block in `tf-scaffold.sh`:

```bash
if is_module_selected "azure-newservice"; then
  echo "# Azure New Service - Private DNS"
  if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
    cat << 'EOF'
module "newservice_dns_existing" {
  count  = var.use_existing_private_dns && var.newservice_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.newservice.pe_private_ip
  dns_zone_name       = "privatelink.newservice.azure.com"  # Use correct zone
  record_name         = var.newservice_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}
EOF
  else
    cat << 'EOF'
module "newservice_dns_standalone" {
  count  = !var.use_existing_private_dns && var.newservice_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.newservice.pe_private_ip
  dns_zone_name      = "privatelink.newservice.azure.com"  # Use correct zone
  record_name        = var.newservice_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}
EOF
  fi
fi
```

**IMPORTANT**: The module reference `module.newservice.pe_private_ip` must match the actual module name declared in `templates/modules/azure-newservice/main.tf`. 

**Existing module name mappings**:
- `azure-acr` → module name: `container_registry`
- `azure-keyvault` → module name: `key_vault`
- `azure-cosmosdb` → module name: `cosmos_db`

For example, if your template declares `module "my_service"`, use `module.my_service.pe_private_ip` (not `module.newservice.pe_private_ip`).

### Step 2: Update PE Module Detection

Add the new module to the PE-enabled modules check:

```bash
# In add_private_dns_modules() and prompt_private_dns_config()
case "$module" in
  azure-acr|azure-keyvault|azure-cosmosdb|azure-newservice)  # Add here
    has_pe_modules=true
    break
    ;;
esac
```

### Step 3: Find the Correct Private DNS Zone Name

Common Private DNS zones:
- ACR: `privatelink.azurecr.io`
- Key Vault: `privatelink.vaultcore.azure.net`
- Cosmos DB (MongoDB): `privatelink.mongo.cosmos.azure.com`
- Cosmos DB (SQL): `privatelink.documents.azure.com`
- Storage Blob: `privatelink.blob.core.windows.net`
- SQL Database: `privatelink.database.windows.net`
- Service Bus: `privatelink.servicebus.windows.net`
- PostgreSQL: `privatelink.postgres.database.azure.com`
- Redis: `privatelink.redis.cache.windows.net`

See: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns

### Step 4: Service Module Requirements

The service module must:
1. Create the service resource
2. Create a Private Endpoint (without `private_dns_zone_group` block)
3. Output the Private Endpoint's private IP:

```hcl
output "pe_private_ip" {
  description = "Private IP address of the Private Endpoint"
  value       = azurerm_private_endpoint.pe.private_service_connection[0].private_ip_address
}
```

## Checklist: When Modifying Templates or Modules

Use this checklist whenever you modify template or module files:

### Adding a New Module

- [ ] Create module directory: `modules/azure-{service}/`
- [ ] Create module files: `main.tf`, `outputs.tf`, `variables.tf`
- [ ] Create template directory: `templates/modules/azure-{service}/`
- [ ] Create template files: `main.tf`, `variables.tf`, `terraform.tfvars`
- [ ] Add module name to `MODULES` array in `tf-scaffold.sh`
- [ ] If Private Endpoint supported:
  - [ ] Add to PE detection in `add_private_dns_modules()`
  - [ ] Add DNS module generation logic
  - [ ] Ensure service module outputs `pe_private_ip`
- [ ] Test scaffold with and without the module selected
- [ ] Update documentation

### Adding Module-Specific Infrastructure

- [ ] Create infrastructure templates in `templates/infrastructure/`:
  - [ ] `azure-{module}-{resource}.tf`
  - [ ] `azure-{module}-{resource}.variables.tf`
  - [ ] `azure-{module}-{resource}.tfvars`
- [ ] Update `generate_main_tf()` function in `tf-scaffold.sh`
- [ ] Update `generate_variables_tf()` function in `tf-scaffold.sh`
- [ ] Update `generate_terraform_tfvars()` function in `tf-scaffold.sh`
- [ ] Remove from base templates if moving from base to conditional
- [ ] Test scaffold with and without the module selected

### Modifying Base Templates

- [ ] Update template in `templates/base/`
- [ ] Verify placeholders are correct (`__PROJECT_NAME__`, `__ENV_NAME__`, etc.)
- [ ] Test scaffold generation
- [ ] Check existing projects aren't broken by changes
- [ ] Update documentation if behavior changes

### Changing Module Structure

- [ ] Update all three locations:
  - [ ] Actual module in `modules/`
  - [ ] Module template in `templates/modules/`
  - [ ] Scaffold generation logic in `tf-scaffold.sh`
- [ ] Test scaffold generation
- [ ] Verify generated configuration works
- [ ] Update documentation

## Testing the Scaffold After Changes

Always test the scaffold script after making changes:

```bash
# Test 1: Generate with new module selected
./tf-scaffold.sh
# Select: testproj, dev, [your-module], DNS mode

# Test 2: Generate without new module
./tf-scaffold.sh
# Select: testproj, dev2, [other-modules], DNS mode

# Test 3: Verify generated files
cd projects/testproj-dev
terraform init
terraform validate
terraform plan

# Clean up test environments
rm -rf projects/testproj-dev*
```

## Common Mistakes to Avoid

1. ❌ **Adding module but forgetting to add to MODULES array**
   - Result: Module never appears in selection menu

2. ❌ **Adding PE support but not updating DNS module generation**
   - Result: Private Endpoints created without DNS registration

3. ❌ **Module template variable names don't match actual module**
   - Result: Generated configuration has undefined variables

4. ❌ **Incorrect module source paths in templates**
   - Expected: `source = "../../modules/azure-acr"`
   - Wrong: `source = "./modules/azure-acr"`

5. ❌ **Not using placeholders in templates**
   - Result: Hard-coded values that don't get substituted

6. ❌ **Adding infrastructure to base that should be conditional**
   - Result: Resources created even when module not needed

7. ❌ **Forgetting to test both scaffold paths (with/without module)**
   - Result: Broken generation in one scenario

## Quick Reference: Scaffold Script Structure

```bash
tf-scaffold.sh
├── Global variables (line ~35-45)
│   └── MODULES array - Add new module names here
│
├── show_module_selector() (line ~50-105)
│   └── Displays module selection menu
│
├── prompt_private_dns_config() (line ~105-170)
│   └── Prompts for DNS configuration
│
├── is_module_selected() (line ~185-195)
│   └── Helper to check if module is selected
│
├── add_private_dns_modules() (line ~195-350)
│   └── Generates DNS module calls - ADD NEW PE SERVICES HERE
│
├── add_private_dns_variables() (line ~450-490)
│   └── Generates DNS variable declarations
│
├── add_private_dns_tfvars() (line ~490-530)
│   └── Generates DNS tfvars values
│
├── generate_main_tf() (line ~215-265)
│   └── Assembles main.tf - ADD CONDITIONAL INFRA HERE
│
├── generate_variables_tf() (line ~350-400)
│   └── Assembles variables.tf - ADD CONDITIONAL VARS HERE
│
├── generate_terraform_tfvars() (line ~300-350)
│   └── Assembles terraform.tfvars - ADD CONDITIONAL TFVARS HERE
│
└── generate_providers_tf() (line ~320-360)
    └── Generates providers.tf with optional dns_sub provider
```

## Additional Resources

- [SCAFFOLD_PRIVATE_DNS.md](../SCAFFOLD_PRIVATE_DNS.md) - Private DNS integration guide
- [PRIVATE_DNS_IMPLEMENTATION.md](../PRIVATE_DNS_IMPLEMENTATION.md) - Complete Private DNS solution
- [modules/PRIVATE_DNS_README.md](../modules/PRIVATE_DNS_README.md) - DNS module documentation
- [SCAFFOLD_USAGE.md](../SCAFFOLD_USAGE.md) - General scaffold usage guide
