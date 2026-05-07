# Bug Fix: Module References and DNS Management

**Date**: 2026-05-07  
**Status**: ✅ Fixed and Validated

## Issue Summary

When running `terraform validate` on the cics-prod project, encountered two critical issues:

### 1. Incorrect Module References in DNS Modules
**Error**: `Error: Reference to undeclared module - No module call named "acr" is declared in the root module`

**Root Cause**: The scaffold script was generating DNS module calls using short names (`module.acr`, `module.keyvault`, `module.cosmosdb`) but the actual module templates use descriptive names (`module "container_registry"`, `module "key_vault"`, `module "cosmos_db"`).

### 2. Conflicting DNS Management
**Error**: `Error: Unsupported attribute - This object does not have an attribute named "pe_private_ip"`

**Root Cause**: Service modules (ACR, KeyVault, CosmosDB) were managing their own DNS zones, VNet links, and A records - the OLD approach. This conflicted with the new service-agnostic DNS modules (`private-dns-registration` and `private-dns-standalone`).

## What Was Fixed

### 1. Scaffold Script DNS Module Generation

Updated `tf-scaffold.sh` to use correct module names in DNS module calls:

**Before** (incorrect):
```hcl
private_ip_address = module.acr.pe_private_ip
private_ip_address = module.keyvault.pe_private_ip
private_ip_address = module.cosmosdb.pe_private_ip
```

**After** (correct):
```hcl
private_ip_address = module.container_registry.pe_private_ip
private_ip_address = module.key_vault.pe_private_ip
private_ip_address = module.cosmos_db.pe_private_ip
```

**Files Changed**:
- [tf-scaffold.sh](tf-scaffold.sh) - Lines 254, 269, 294, 309, 334, 349

### 2. Service Modules Refactored

Removed DNS resource management from service modules to use the service-agnostic DNS approach:

#### azure-acr Module
**Removed**:
- `azurerm_private_dns_zone.acr` - DNS zone creation
- `azurerm_private_dns_zone_virtual_network_link.acr` - VNet link
- `azurerm_private_dns_a_record.acr` - Primary A record
- `azurerm_private_dns_a_record.acr_data` - Data endpoint A record

**Output Changed**:
- `private_endpoint_ip` → `pe_private_ip` (standardized name)
- Removed: `private_dns_zone_id` (no longer creating zones)

#### azure-keyvault Module
**Removed**:
- `azurerm_private_dns_zone.keyvault` - DNS zone creation
- `azurerm_private_dns_zone_virtual_network_link.keyvault` - VNet link
- `azurerm_private_dns_a_record.keyvault` - A record

**Output Changed**:
- `private_endpoint_ip` → `pe_private_ip` (standardized name)
- Removed: `private_dns_zone_id`

#### azure-cosmosdb Module
**Removed**:
- `azurerm_private_dns_zone.cosmosdb` - DNS zone creation
- `azurerm_private_dns_zone_virtual_network_link.cosmosdb` - VNet link
- `azurerm_private_dns_a_record.cosmosdb` - A record

**Output Changed**:
- `private_endpoint_ip` → `pe_private_ip` (standardized name)
- Removed: `private_dns_zone_id`

### 3. Documentation Updated

Updated guidance documents to reflect correct module name mappings:

**Files Updated**:
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Added module name mapping section
- `~/.agents/skills/terraform-scaffold-consistency/SKILL.md` - Added module name mapping warnings

**Added Section**:
```markdown
**Module name mappings**:
- `azure-acr` → module declared as: `module "container_registry"`
- `azure-keyvault` → module declared as: `module "key_vault"`
- `azure-cosmosdb` → module declared as: `module "cosmos_db"`
```

## Architecture: Old vs New Approach

### Old Approach (Each Service Manages DNS)
```
┌─────────────────┐
│   ACR Module    │
│  ┌───────────┐  │
│  │ ACR       │  │
│  │ PE        │  │
│  │ DNS Zone  │  │ ← Each service creates its own DNS
│  │ VNet Link │  │
│  │ A Records │  │
│  └───────────┘  │
└─────────────────┘

Problems:
❌ Duplicate DNS zones
❌ Hard to manage centrally
❌ Can't use existing DNS infrastructure
```

### New Approach (Service-Agnostic DNS)
```
┌─────────────────┐     ┌──────────────────────┐
│   ACR Module    │     │ Private DNS Module   │
│  ┌───────────┐  │     │  ┌───────────────┐   │
│  │ ACR       │  │────▶│  │ DNS Zone      │   │
│  │ PE        │  │  IP │  │ A Record      │   │
│  └───────────┘  │     │  │ VNet Link     │   │
└─────────────────┘     │  └───────────────┘   │
                        └──────────────────────┘
┌─────────────────┐            ▲
│ KeyVault Module │────────────┤
│  ┌───────────┐  │  Shared IP │ ← One DNS module
│  │ KV   │ PE │  │            │   handles all services
│  └───────────┘  │            │
└─────────────────┘            │
┌─────────────────┐            │
│ CosmosDB Module │────────────┘
│  ┌───────────┐  │  PE IPs only
│  │ DB   │ PE │  │
│  └───────────┘  │
└─────────────────┘

Benefits:
✅ Service-agnostic DNS handling
✅ Can use existing DNS zones
✅ Works across subscriptions
✅ Centralized DNS management
```

## Service Module Design Pattern

### What Service Modules Should Do
```hcl
# 1. Create the service resource
resource "azurerm_container_registry" "main" {
  # ... ACR config
}

# 2. Create Private Endpoint (NO DNS zone group)
resource "azurerm_private_endpoint" "acr" {
  # ... PE config
  # NO private_dns_zone_group block
}

# 3. Output Private IP for DNS registration
output "pe_private_ip" {
  value = azurerm_private_endpoint.acr[0].private_service_connection[0].private_ip_address
}
```

### What Service Modules Should NOT Do
```hcl
# ❌ Don't create DNS zones
resource "azurerm_private_dns_zone" "..." { }

# ❌ Don't create VNet links
resource "azurerm_private_dns_zone_virtual_network_link" "..." { }

# ❌ Don't create A records
resource "azurerm_private_dns_a_record" "..." { }

# ❌ Don't add DNS zone group to PE
resource "azurerm_private_endpoint" "..." {
  private_dns_zone_group { } # ← Don't do this
}
```

## Testing Results

### Before Fix
```bash
$ terraform validate
Error: Reference to undeclared module
  on main.tf line 87, in module "acr_dns_existing":
  87:   private_ip_address  = module.acr.pe_private_ip
No module call named "acr" is declared in the root module.
```

### After Fix
```bash
$ terraform validate
Success! The configuration is valid.
```

## Files Modified

### Scaffold Script
- ✅ [tf-scaffold.sh](tf-scaffold.sh) - Fixed 6 module references

### Service Modules
- ✅ [modules/azure-acr/main.tf](modules/azure-acr/main.tf) - Removed DNS management
- ✅ [modules/azure-acr/outputs.tf](modules/azure-acr/outputs.tf) - Standardized output name
- ✅ [modules/azure-keyvault/main.tf](modules/azure-keyvault/main.tf) - Removed DNS management
- ✅ [modules/azure-keyvault/outputs.tf](modules/azure-keyvault/outputs.tf) - Standardized output name
- ✅ [modules/azure-cosmosdb/main.tf](modules/azure-cosmosdb/main.tf) - Removed DNS management
- ✅ [modules/azure-cosmosdb/outputs.tf](modules/azure-cosmosdb/outputs.tf) - Standardized output name

### Project Config
- ✅ [projects/cics-prod/main.tf](projects/cics-prod/main.tf) - Fixed module reference

### Documentation
- ✅ [.github/copilot-instructions.md](.github/copilot-instructions.md) - Added module mapping section
- ✅ `~/.agents/skills/terraform-scaffold-consistency/SKILL.md` - Added module mapping warnings

## Impact on Existing Projects

### For New Projects
- ✅ Scaffold script now generates correct module references
- ✅ DNS modules work out of the box
- ✅ Can choose standalone or cross-subscription DNS

### For Existing Projects (Created Before Fix)
If you generated a project before this fix, you need to:

1. **Update main.tf** - Fix module references:
   ```bash
   # Find and replace in main.tf
   module.acr.pe_private_ip → module.container_registry.pe_private_ip
   module.keyvault.pe_private_ip → module.key_vault.pe_private_ip
   module.cosmosdb.pe_private_ip → module.cosmos_db.pe_private_ip
   ```

2. **No need to regenerate** - Just fix the module references, terraform validate will pass

## Key Learnings

### 1. Module Names Must Match
The module name in the module call must match the reference name used elsewhere:
```hcl
# If you declare:
module "container_registry" { ... }

# You must reference it as:
module.container_registry.pe_private_ip
```

### 2. Service-Agnostic Design
Separating concerns (service creation vs DNS management) provides:
- Flexibility to use existing DNS infrastructure
- Reusability across different services
- Cleaner module responsibilities

### 3. Consistent Output Names
Using `pe_private_ip` across all modules makes DNS module integration predictable and maintainable.

## Prevention: terraform-scaffold-consistency Skill

The `terraform-scaffold-consistency` skill was created to prevent this type of issue in the future. It will:
- Remind about scaffold updates when templates change
- Show correct module name mappings
- Provide testing procedures
- Catch common mistakes

See [SCAFFOLD_CONSISTENCY_SETUP.md](SCAFFOLD_CONSISTENCY_SETUP.md) for details.

## Validation

✅ Scaffold script syntax valid: `bash -n tf-scaffold.sh`  
✅ Module references correct  
✅ DNS management removed from service modules  
✅ Output names standardized to `pe_private_ip`  
✅ Documentation updated  
✅ Terraform validation passes: `terraform validate` in cics-prod  

## Next Steps

1. ✅ Scaffold generates correct configurations
2. ✅ Service modules follow service-agnostic pattern
3. ✅ DNS modules handle registration
4. ✅ Documentation guides future development
5. 🎯 Deploy and test in Azure environment

---

**Summary**: Fixed module reference mismatch between scaffold-generated code and template definitions, refactored service modules to use service-agnostic DNS approach, standardized output naming across all modules. Configuration now validates successfully.
