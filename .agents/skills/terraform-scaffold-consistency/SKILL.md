---
description: >
  Maintain consistency between Terraform templates, modules, and the tf-scaffold.sh script.
  Use when creating, modifying, or debugging templates, modules, infrastructure resources, 
  or the scaffold script. Ensures scaffold script stays in sync with template changes.
  Trigger phrases: "add module", "create template", "modify scaffold", "update infrastructure",
  "new azure service", "private endpoint support", "scaffold not generating", "template changes not reflected"
---

# Terraform Scaffold Consistency Skill

## Purpose

This skill ensures that modifications to Terraform templates, modules, and infrastructure are properly reflected in the `tf-scaffold.sh` script. The scaffold script dynamically generates environment configurations, so it must stay synchronized with template structure.

## When to Use This Skill

Invoke this skill when:
- ✅ Adding a new Azure service module
- ✅ Modifying existing module templates
- ✅ Adding module-specific infrastructure (subnets, NSGs, etc.)
- ✅ Adding Private Endpoint support to a service
- ✅ Changing base template structure
- ✅ Debugging scaffold generation issues
- ✅ Template changes not appearing in generated files
- ✅ User mentions "scaffold", "template", "module consistency"

## Project Structure Context

```
.
├── tf-scaffold.sh                    # Main scaffold script - MUST UPDATE
├── templates/
│   ├── base/                         # Base infrastructure (always included)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   ├── backend.hcl
│   │   └── providers.tf
│   ├── infrastructure/               # Conditional infrastructure
│   │   ├── azure-{module}-{resource}.tf
│   │   ├── azure-{module}-{resource}.variables.tf
│   │   └── azure-{module}-{resource}.tfvars
│   └── modules/                      # Module templates (conditionally included)
│       └── azure-{service}/
│           ├── main.tf               # Module call template
│           ├── variables.tf          # Module variable declarations
│           └── terraform.tfvars      # Module default values
├── modules/                          # Actual Terraform modules
│   ├── azure-acr/
│   ├── azure-aks/
│   ├── azure-keyvault/
│   ├── private-dns-registration/    # Cross-sub DNS
│   └── private-dns-standalone/      # Standalone DNS
└── projects/                         # Generated environments
    └── {project}-{env}/              # Output from scaffold
```

## Critical Rules

### 1. Template Changes → Scaffold Updates Required

**ALWAYS check and update tf-scaffold.sh when modifying:**
- Adding/removing modules
- Changing template file names
- Adding Private Endpoint support
- Adding conditional infrastructure
- Modifying base template structure

### 2. Module Source Paths

Templates use relative paths from generated project directory:
- ✅ Correct: `source = "../../modules/azure-acr"`
- ❌ Wrong: `source = "./modules/azure-acr"`
- ❌ Wrong: `source = "../modules/azure-acr"`

### 3. Placeholder Substitution

Templates use these placeholders (case-sensitive):
- `__PROJECT_NAME__` → Project name (e.g., "cics")
- `__ENV_NAME__` → Environment name (e.g., "dev")
- `__ENV_NAME_UPPER__` → Environment uppercase (e.g., "DEV")
- `__DATE__` → Current date (e.g., "2026-05-07")

## Workflow: Adding a New Module

### Step 1: Check Prerequisites

```bash
# Verify module exists
ls -la modules/azure-{service}/

# Check template directory structure
ls -la templates/modules/azure-{service}/
```

### Step 2: Update MODULES Array

Location: `tf-scaffold.sh` (around line 30-40)

```bash
declare -a MODULES=(
  "azure-acr"
  "azure-aks"
  "azure-cosmosdb"
  "azure-keyvault"
  "azure-redis"
  "azure-vm"
  "azure-{newservice}"  # ← ADD HERE
)
```

### Step 3: Create Module Templates

Required files in `templates/modules/azure-{service}/`:

**main.tf** - Module call template:
```hcl
# ===================================================================
# Azure {Service} Module
# ===================================================================

module "{service}" {
  source = "../../modules/azure-{service}"
  
  {service}_name          = var.{service}_name
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  tags                    = var.tags
  
  # Add service-specific variables
}
```

**variables.tf** - Variable declarations:
```hcl
variable "{service}_name" {
  description = "Name of the {Service}"
  type        = string
}

# Add other service-specific variables
```

**terraform.tfvars** - Default values:
```hcl
# ===================================================================
# Azure {Service} Configuration
# ===================================================================

{service}_name = "__PROJECT_NAME__-{service}-__ENV_NAME__"
```

### Step 4: Test Scaffold Generation

```bash
# Generate test environment
./tf-scaffold.sh
# Select: testproj, dev, [new-module]

# Verify files
cat projects/testproj-dev/main.tf | grep "module \"{service}\""
cat projects/testproj-dev/variables.tf | grep "{service}_name"
cat projects/testproj-dev/terraform.tfvars | grep "{service}_name"

# Validate Terraform
cd projects/testproj-dev
terraform init
terraform validate

# Clean up
cd ../..
rm -rf projects/testproj-dev
```

## Workflow: Adding Private Endpoint Support

### Step 1: Verify Service Module Outputs PE IP

In `modules/azure-{service}/outputs.tf`:

```hcl
output "pe_private_ip" {
  description = "Private IP address of the Private Endpoint"
  value       = azurerm_private_endpoint.pe.private_service_connection[0].private_ip_address
}
```

### Step 2: Find Private DNS Zone Name

Common zones:
- ACR: `privatelink.azurecr.io`
- Key Vault: `privatelink.vaultcore.azure.net`
- Cosmos DB MongoDB: `privatelink.mongo.cosmos.azure.com`
- Storage Blob: `privatelink.blob.core.windows.net`
- SQL DB: `privatelink.database.windows.net`

See: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns

### Step 3: Update PE Module Detection (CRITICAL - Multiple Locations)

**IMPORTANT**: When adding a Private Endpoint-enabled module, you MUST update the module name in **FOUR** locations in `tf-scaffold.sh`. Missing any location will break DNS auto-detection or generation.

#### Location 1: DNS Auto-Detection Logic (~line 875)

This determines if DNS configuration prompt is needed based on `.env` file.

```bash
# Check if DNS configuration is needed (any module with Private Endpoint support)
local needs_dns=false
for module in "${SELECTED_MODULES[@]}"; do
  case "$module" in
    azure-acr|azure-keyvault|azure-cosmosdb|azure-redis|azure-{newservice})  # ← ADD HERE
      needs_dns=true
      break
      ;;
  esac
done
```

**Why critical**: Without this, when users select only your new service:
- ❌ DNS mode won't be auto-detected from `.env`
- ❌ Will default to standalone mode with wrong RG name
- ❌ Terraform will fail with "Resource group not found"

#### Location 2: add_private_dns_modules() - PE Detection (~line 230)

This checks if DNS modules should be generated at all.

```bash
# In add_private_dns_modules() function
local has_pe_modules=false

# Check if any module with Private Endpoint support is selected
for module in "${SELECTED_MODULES[@]}"; do
  case "$module" in
    azure-acr|azure-keyvault|azure-cosmosdb|azure-redis|azure-{newservice})  # ← ADD HERE
      has_pe_modules=true
      break
      ;;
  esac
done
```

#### Location 3: add_private_dns_variables() - PE Detection (~line 420)

This checks if DNS variables should be added to variables.tf.

```bash
# In add_private_dns_variables() function
local has_pe_modules=false

# Check if any module with Private Endpoint support is selected
for module in "${SELECTED_MODULES[@]}"; do
  case "$module" in
    azure-acr|azure-keyvault|azure-cosmosdb|azure-redis|azure-{newservice})  # ← ADD HERE
      has_pe_modules=true
      break
      ;;
  esac
done
```

#### Location 4: add_private_dns_tfvars() - PE Detection (~line 465)

This checks if DNS tfvars should be added to terraform.tfvars.

```bash
# In add_private_dns_tfvars() function
local has_pe_modules=false

# Check if any module with Private Endpoint support is selected
for module in "${SELECTED_MODULES[@]}"; do
  case "$module" in
    azure-acr|azure-keyvault|azure-cosmosdb|azure-redis|azure-{newservice})  # ← ADD HERE
      has_pe_modules=true
      break
      ;;
  esac
done
```

**Quick Verification**:
```bash
# After adding service, verify it appears in all 4 locations
grep -n "azure-{newservice}" tf-scaffold.sh | grep "case"
# Should show 4 matches at different line numbers
```

### Step 3a: Understanding DNS Auto-Detection from .env

The scaffold automatically determines DNS mode by reading `.env` file:

**Cross-Subscription Mode** (use existing DNS zones):
```bash
# .env file contains:
DNS_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
DNS_ZONE_RG="rg-private-dns"

# Result in terraform.tfvars:
use_existing_private_dns = true
dns_subscription_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
dns_zone_rg              = "rg-private-dns"

# Uses: private-dns-registration module (cross-subscription)
```

**Standalone Mode** (create new DNS zones):
```bash
# .env file has empty or missing DNS values:
DNS_SUBSCRIPTION_ID=""
DNS_ZONE_RG=""

# Result in terraform.tfvars:
use_existing_private_dns = false
dns_zone_rg              = "rg-{project}-{env}-dns"  # Auto-generated name

# Uses: private-dns-standalone module (same subscription)
```

**The auto-detection logic** (around line 884-900):
```bash
if [ -n "$DNS_SUBSCRIPTION_ID" ] && [ -n "$DNS_ZONE_RG" ]; then
  # Both values present → Cross-Subscription mode
  USE_EXISTING_PRIVATE_DNS="true"
else
  # Missing values → Standalone mode
  USE_EXISTING_PRIVATE_DNS="false"
  DNS_ZONE_RG="rg-${PROJECT_NAME}-${ENV_NAME}-dns"
fi
```

**Why this matters**: Users don't manually choose DNS mode anymore. The scaffold reads `.env` and automatically configures the correct mode. If your service isn't in the detection list (Step 3 above), DNS auto-detection won't trigger when only your service is selected.

### Step 4: Add DNS Module Generation Logic

Location: `tf-scaffold.sh` in `add_private_dns_modules()` function (around line 250-350)

Add after existing service DNS blocks:

```bash
if is_module_selected "azure-{service}"; then
  echo "# Azure {Service} - Private DNS"
  if [ "$USE_EXISTING_PRIVATE_DNS" = "true" ]; then
    cat << 'EOF'
module "{service}_dns_existing" {
  count  = var.use_existing_private_dns && var.{service}_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.{service}.pe_private_ip
  dns_zone_name       = "privatelink.{service}.azure.com"  # ← CORRECT ZONE
  record_name         = var.{service}_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

EOF
  else
    cat << 'EOF'
module "{service}_dns_standalone" {
  count  = !var.use_existing_private_dns && var.{service}_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.{service}.pe_private_ip
  dns_zone_name      = "privatelink.{service}.azure.com"  # ← CORRECT ZONE
  record_name        = var.{service}_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

EOF
  fi
fi
```

**CRITICAL**: The module reference `module.{service}.pe_private_ip` must match the actual module name in `templates/modules/azure-{service}/main.tf`.

**Module name mappings**:
- `azure-acr` → module declared as: `module "container_registry"`
- `azure-keyvault` → module declared as: `module "key_vault"`
- `azure-cosmosdb` → module declared as: `module "cosmos_db"`

Example: For ACR, use `module.container_registry.pe_private_ip` (not `module.acr.pe_private_ip`).

### Step 5: Test Both DNS Modes

```bash
# Test standalone mode
./tf-scaffold.sh
# Select: testproj, dev, [service], DNS mode: 1

cat projects/testproj-dev/main.tf | grep "{service}_dns_standalone"

# Test cross-subscription mode
./tf-scaffold.sh
# Select: testproj, prod, [service], DNS mode: 2
# DNS Sub ID: test-sub-id
# DNS RG: rg-dns-hub

cat projects/testproj-prod/main.tf | grep "{service}_dns_existing"
cat projects/testproj-prod/providers.tf | grep "dns_sub"

# Clean up
rm -rf projects/testproj-*
```

## Workflow: Adding Conditional Infrastructure

Use this for module-specific resources (subnets, NSGs, route tables) that should only exist when the module is selected.

### Step 1: Create Infrastructure Templates

Create three files in `templates/infrastructure/`:

```bash
# Resource definition
templates/infrastructure/azure-{module}-{resource}.tf

# Variable declarations
templates/infrastructure/azure-{module}-{resource}.variables.tf

# Variable values
templates/infrastructure/azure-{module}-{resource}.tfvars
```

Example for AKS subnet:

**azure-aks-subnet.tf**:
```hcl
# AKS Subnet - for Azure Kubernetes Service nodes
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.project_name}-${var.environment}-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefixes
}
```

**azure-aks-subnet.variables.tf**:
```hcl
variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet"
  type        = list(string)
  default     = ["10.10.3.0/24"]
}
```

**azure-aks-subnet.tfvars**:
```hcl
aks_subnet_address_prefixes = ["10.10.3.0/24"]
```

### Step 2: Update generate_main_tf()

Location: `tf-scaffold.sh` around line 220-260

Find the infrastructure conditional block and add:

```bash
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  # Existing conditionals...
  
  # Add new conditional
  if is_module_selected "azure-{module}"; then
    local module_infra="${infra_dir}/azure-{module}-{resource}.tf"
    if [ -f "$module_infra" ]; then
      echo "" >> "$output_file"
      cat "$module_infra" >> "$output_file"
    fi
  fi
fi
```

### Step 3: Update generate_variables_tf()

Location: `tf-scaffold.sh` around line 360-400

Add similar conditional:

```bash
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  if is_module_selected "azure-{module}"; then
    local module_vars="${infra_dir}/azure-{module}-{resource}.variables.tf"
    if [ -f "$module_vars" ]; then
      cat "$module_vars" >> "$output_file"
    fi
  fi
fi
```

### Step 4: Update generate_terraform_tfvars()

Location: `tf-scaffold.sh` around line 310-350

Add similar conditional:

```bash
local infra_dir="${TEMPLATES_DIR}/infrastructure"
if [ -d "$infra_dir" ]; then
  if is_module_selected "azure-{module}"; then
    local module_tfvars="${infra_dir}/azure-{module}-{resource}.tfvars"
    if [ -f "$module_tfvars" ]; then
      cat "$module_tfvars" >> "$output_file"
    fi
  fi
fi
```

### Step 5: Test Conditional Inclusion

```bash
# Generate WITH module - should include infrastructure
./tf-scaffold.sh
# Select: test1, dev, [module-with-infra]
grep "{resource}" projects/test1-dev/main.tf
# Should find the resource

# Generate WITHOUT module - should NOT include infrastructure
./tf-scaffold.sh
# Select: test2, dev, [other-modules]
grep "{resource}" projects/test2-dev/main.tf
# Should not find the resource

# Clean up
rm -rf projects/test*
```

## Common Issues and Solutions

### Issue 1: Module Not Appearing in Selection Menu

**Symptom**: New module doesn't show up when running scaffold

**Check**:
```bash
grep "azure-{service}" tf-scaffold.sh | grep "MODULES="
```

**Solution**: Add module to `MODULES` array (line ~30-40)

### Issue 2: Generated Files Have Wrong Module Paths

**Symptom**: `terraform init` fails with "module not found"

**Check**:
```bash
cat projects/test-dev/main.tf | grep "source ="
```

**Expected**: `source = "../../modules/azure-acr"`
**Wrong**: `source = "./modules/azure-acr"`

**Solution**: Fix module source paths in template files

### Issue 3: Private DNS Not Generated

**Symptom**: PE created but no DNS modules in generated main.tf

**Check**:
```bash
# Check if service is in PE detection list
grep "azure-{service}" tf-scaffold.sh | grep "case"
```

**Solution**: Add service to case statement in `add_private_dns_modules()`

### Issue 4: Placeholders Not Substituted

**Symptom**: Generated files contain `__PROJECT_NAME__` literally

**Check**:
```bash
grep "__PROJECT_NAME__" projects/test-dev/*.tf
```

**Solution**: Ensure template files use correct placeholder names (case-sensitive)

### Issue 5: Conditional Infrastructure Always Included

**Symptom**: Infrastructure appears even when module not selected

**Check**:
```bash
# Look for guard condition
grep "is_module_selected.*{module}" tf-scaffold.sh
```

**Solution**: Wrap infrastructure inclusion in `is_module_selected "{module}"` check

### Issue 6: DNS Auto-Detection Not Triggered for New PE Module

**Symptom**: 
- `.env` has `DNS_SUBSCRIPTION_ID` and `DNS_ZONE_RG` populated
- Generated project has `use_existing_private_dns = false` (wrong!)
- Terraform fails: "Resource group 'rg-private-dns' could not be found"

**Root Cause**: New PE-enabled service not added to DNS auto-detection case statement

**Check**:
```bash
# Verify service appears in all 4 case statements
grep -n "azure-{service}" tf-scaffold.sh | grep "case"
# Should show 4 matches (auto-detection + 3 generation functions)
```

**Solution**: Add service to **ALL FOUR** case statements:
1. DNS auto-detection logic (~line 875)
2. `add_private_dns_modules()` (~line 230)
3. `add_private_dns_variables()` (~line 420)
4. `add_private_dns_tfvars()` (~line 465)

**Verification After Fix**:
```bash
# Delete old project
rm -rf projects/{project}-{env}

# Regenerate (should now pick up DNS mode from .env)
./tf-scaffold.sh

# Check generated config
cat projects/{project}-{env}/terraform.tfvars | grep "use_existing_private_dns"
# Should show: use_existing_private_dns = true (if .env has DNS values)
```

### Issue 7: Wrong DNS Module Module Reference

**Symptom**: `terraform plan` fails with "module.{service}.pe_private_ip not found"

**Root Cause**: Module name mismatch between template declaration and DNS module reference

**Check Module Name**:
```bash
# What's the module declared as in template?
grep "^module " templates/modules/azure-{service}/main.tf
# Output: module "container_registry" {  ← This is the actual name
```

**Common Mismatches**:
- `azure-acr` → module name: `container_registry` (not `acr`)
- `azure-keyvault` → module name: `key_vault` (not `keyvault`)
- `azure-cosmosdb` → module name: `cosmos_db` (not `cosmosdb`)

**Solution**: Update DNS module generation to use correct module reference:
```bash
# In scaffold DNS generation:
private_ip_address = module.container_registry.pe_private_ip  # ✓ Correct
# NOT:
private_ip_address = module.acr.pe_private_ip  # ✗ Wrong
```

## Testing Checklist

After any scaffold or template changes:

**General Changes:**
- [ ] Syntax check: `bash -n tf-scaffold.sh`
- [ ] Generate with new module selected
- [ ] Generate without new module (verify exclusion)
- [ ] Verify placeholders substituted correctly
- [ ] Check module source paths are relative (`../../modules/`)
- [ ] Test Terraform validation: `terraform init && terraform validate`
- [ ] Clean up test projects: `rm -rf projects/test*`

**Private Endpoint-Enabled Modules (Additional Checks):**
- [ ] Added to MODULES array
- [ ] Added to DNS auto-detection logic (~line 875) - `needs_dns` check
- [ ] Added to `add_private_dns_modules()` PE detection (~line 230)
- [ ] Added to `add_private_dns_variables()` PE detection (~line 420)
- [ ] Added to `add_private_dns_tfvars()` PE detection (~line 465)
- [ ] Verify all 4 case statements: `grep -n "azure-{service}" tf-scaffold.sh | grep "case"`
- [ ] Test with .env having DNS values (cross-subscription mode)
- [ ] Test with .env having empty DNS values (standalone mode)
- [ ] Test service module outputs `pe_private_ip`
- [ ] Verify correct Private DNS zone name used
- [ ] Test conditional infrastructure (if applicable)

## Quick Reference Commands

```bash
# Validate scaffold syntax
bash -n tf-scaffold.sh

# Run scaffold interactively
./tf-scaffold.sh

# Check what's in MODULES array
grep -A 10 "declare -a MODULES" tf-scaffold.sh

# Find where module is referenced
grep -n "azure-{service}" tf-scaffold.sh

# Verify PE module in all 4 case statements (should show 4 matches)
grep -n "azure-{service}" tf-scaffold.sh | grep "case"

# Test generation
./tf-scaffold.sh <<EOF
testproj
dev
1
1
rg-test-dns
EOF

# Validate generated config
cd projects/testproj-dev && terraform init && terraform validate

# Clean test environments
rm -rf projects/test* projects/*-dev projects/*-test
```

## TL;DR: Adding a Private Endpoint-Enabled Module

**The 4-Location Rule**: When adding a PE-enabled Azure service, update these 4 locations in `tf-scaffold.sh`:

```bash
# ✓ Location 1: Line ~875 - DNS Auto-Detection
case "$module" in
  azure-acr|...|azure-{newservice})  # ← ADD

# ✓ Location 2: Line ~230 - add_private_dns_modules() 
case "$module" in
  azure-acr|...|azure-{newservice})  # ← ADD

# ✓ Location 3: Line ~420 - add_private_dns_variables()
case "$module" in
  azure-acr|...|azure-{newservice})  # ← ADD

# ✓ Location 4: Line ~465 - add_private_dns_tfvars()
case "$module" in
  azure-acr|...|azure-{newservice})  # ← ADD
```

**Verification**:
```bash
# Should show exactly 4 matches
grep -n "azure-{newservice}" tf-scaffold.sh | grep "case"
```

**Why All 4?**
1. **Auto-detection** - Reads `.env` DNS settings
2. **Module generation** - Creates DNS module calls
3. **Variables** - Adds DNS variable declarations  
4. **Tfvars** - Adds DNS variable values

**Forget even ONE location** = DNS won't work correctly when only your service is selected! ⚠️

## Documentation References

- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Complete scaffolding patterns
- [SCAFFOLD_PRIVATE_DNS.md](SCAFFOLD_PRIVATE_DNS.md) - Private DNS integration guide
- [SCAFFOLD_INTEGRATION_SUMMARY.md](SCAFFOLD_INTEGRATION_SUMMARY.md) - Technical details
- [PRIVATE_DNS_IMPLEMENTATION.md](PRIVATE_DNS_IMPLEMENTATION.md) - DNS architecture

## Success Criteria

After using this skill, verify:

1. ✅ New module appears in scaffold selection menu
2. ✅ Generated files include module configuration
3. ✅ Placeholders correctly substituted
4. ✅ Module source paths are correct
5. ✅ Conditional logic works (with/without module)
6. ✅ Private DNS generated if applicable
7. ✅ Terraform validation passes
8. ✅ Documentation updated if needed

## Remember

> **"Templates define structure. Scaffold implements logic. They must stay in sync."**

Always update `tf-scaffold.sh` when modifying:
- Module templates
- Infrastructure templates
- Base templates
- Module structure
- Private Endpoint support

**Critical for Private Endpoint modules**: Update **4 locations** in scaffold:
1. DNS auto-detection (~line 875)
2. `add_private_dns_modules()` (~line 230)
3. `add_private_dns_variables()` (~line 420)
4. `add_private_dns_tfvars()` (~line 465)

**Verification command**: `grep -n "azure-{service}" tf-scaffold.sh | grep "case"` should show **4 matches**.

**DNS Auto-Detection Logic**:
- `.env` has `DNS_SUBSCRIPTION_ID` + `DNS_ZONE_RG` → **Cross-Subscription** mode (use existing DNS zones)
- `.env` missing DNS values → **Standalone** mode (create new DNS zones)
- No manual selection needed - scaffold reads `.env` automatically
