# Private DNS Integration in tf-scaffold.sh

## Overview

The `tf-scaffold.sh` script now includes interactive Private DNS configuration when you select modules that support Private Endpoints (ACR, Key Vault, CosmosDB).

## What Changed

### 1. New Prompts

When you run `./tf-scaffold.sh` and select modules with Private Endpoint support, you'll see:

```
═══════════════════════════════════════════════════
  Private DNS Configuration
═══════════════════════════════════════════════════

Private Endpoints require DNS configuration for name resolution.
Choose your DNS strategy:

  1. Standalone DNS (Create DNS zones in same subscription)
     • Simpler setup, no cross-subscription complexity
     • Suitable for dev/test or single-subscription environments
     • Each environment has its own Private DNS Zones

  2. Cross-Subscription DNS (Use existing DNS zones in hub subscription)
     • Enterprise-grade, centralized DNS management
     • Requires existing Private DNS Zones in a DNS/Hub subscription
     • Requires VNet peering between workload and hub VNets
     • Requires RBAC permissions in DNS subscription

Select DNS mode (1 or 2) [default: 1]:
```

### 2. Automatic DNS Module Generation

Based on your selection, the script automatically generates:

#### For Standalone Mode (Option 1):
- DNS module calls using `private-dns-standalone`
- Creates new Private DNS Zones in workload subscription
- Generates VNet Links automatically
- No cross-subscription configuration needed

#### For Cross-Subscription Mode (Option 2):
- DNS module calls using `private-dns-registration`
- References existing Private DNS Zones in DNS subscription
- Adds `azurerm.dns_sub` provider to `providers.tf`
- Prompts for DNS Subscription ID and DNS Resource Group
- Includes RBAC prerequisite warnings

### 3. Generated Configuration

The scaffold automatically adds to your generated files:

**main.tf** - DNS module calls for each service:
```hcl
# Azure Container Registry - Private DNS
module "acr_dns_standalone" {
  count  = !var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.acr.pe_private_ip
  dns_zone_name      = "privatelink.azurecr.io"
  record_name        = var.acr_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}
```

**variables.tf** - DNS configuration variables:
```hcl
variable "use_existing_private_dns" {
  description = "Use existing Private DNS Zones in separate subscription (true) or create standalone zones (false)"
  type        = bool
  default     = false
}

variable "dns_zone_rg" {
  description = "Resource Group for DNS Zones"
  type        = string
}
```

**terraform.tfvars** - DNS values:
```hcl
# Standalone DNS mode: Creates new Private DNS Zones in workload subscription
use_existing_private_dns = false
dns_zone_rg              = "rg-myproject-dev-dns"
```

**providers.tf** - Cross-sub provider (only if cross-sub mode selected):
```hcl
provider "azurerm" {
  alias           = "dns_sub"
  subscription_id = var.dns_subscription_id
  tenant_id       = var.tenant_id
  features {}
}
```

## Which Modules Trigger DNS Prompts?

The DNS configuration prompt appears when you select ANY of these modules:
- ✅ `azure-acr` (Azure Container Registry)
- ✅ `azure-keyvault` (Azure Key Vault)
- ✅ `azure-cosmosdb` (Azure Cosmos DB)

Other modules (AKS, Redis, VM) don't trigger DNS prompts as they typically don't use Private Endpoints in the same way.

## Example Workflow

### Scenario 1: Dev Environment with Standalone DNS

```bash
$ ./tf-scaffold.sh

Project name: myproject
Environment name: dev

Available modules:
  1. azure-acr
  2. azure-aks
  3. azure-cosmosdb
  4. azure-keyvault
  5. azure-redis
  6. azure-vm

Enter module numbers: 1 4

[Private DNS prompt appears]

Select DNS mode (1 or 2) [default: 1]: 1

DNS Resource Group name: rg-myproject-dev-dns

✓ Environment scaffolded successfully!
```

**Result**: 
- Generates standalone DNS configuration
- Creates `private-dns-standalone` module calls
- No cross-subscription complexity

### Scenario 2: Production with Cross-Subscription DNS

```bash
$ ./tf-scaffold.sh

Project name: myproject
Environment name: prod

Enter module numbers: 1 4

[Private DNS prompt appears]

Select DNS mode (1 or 2): 2

DNS Subscription ID: zzzz-zzzz-zzzz-zzzz
DNS Resource Group name: rg-dns-hub-prod

Note: Ensure the following prerequisites are met:
  • Private DNS Zones exist in DNS subscription
  • VNet Links configured to hub VNet
  • VNet peering established between workload and hub VNets
  • RBAC: 'Private DNS Zone Contributor' role in DNS subscription

✓ Environment scaffolded successfully!
```

**Result**:
- Generates cross-subscription DNS configuration
- Creates `private-dns-registration` module calls
- Adds `azurerm.dns_sub` provider
- Includes prerequisite warnings

## Generated Summary

The scaffold now shows DNS configuration in the generation summary:

```
═══════════════════════════════════════════════════
  Generation Summary
═══════════════════════════════════════════════════

Modules included:
  ✓ azure-acr
  ✓ azure-keyvault

Private DNS Configuration:
  ✓ Mode: Standalone (creates new DNS zones)
  ✓ DNS Resource Group: rg-myproject-dev-dns
```

## Common DNS Zone Names

The scaffold automatically uses the correct `privatelink` zone for each service:

| Service Module | DNS Zone Name |
|---------------|---------------|
| azure-acr | `privatelink.azurecr.io` |
| azure-keyvault | `privatelink.vaultcore.azure.net` |
| azure-cosmosdb | `privatelink.mongo.cosmos.azure.com` |

## Skipping DNS Configuration

If you only select modules without Private Endpoint support (e.g., only `azure-aks` or `azure-vm`), the DNS prompt is automatically skipped.

## Validation

After generation, review:

1. **main.tf** - DNS module calls are present and conditional
2. **variables.tf** - DNS variables are declared
3. **terraform.tfvars** - DNS configuration values match your selection
4. **providers.tf** - Cross-sub provider exists only if needed

## Next Steps After Generation

1. **Review generated files** in `projects/{project}-{env}/`
2. **Update terraform.tfvars** if needed (DNS resource group names, etc.)
3. **For cross-subscription mode**:
   - Verify DNS subscription access
   - Ensure VNet peering is configured
   - Validate RBAC permissions
4. **Run Terraform**:
   ```bash
   cd projects/myproject-dev
   terraform init
   terraform plan
   terraform apply
   ```

## Troubleshooting

### DNS Prompt Not Appearing

**Cause**: No Private Endpoint-enabled modules selected

**Solution**: Select at least one of: `azure-acr`, `azure-keyvault`, or `azure-cosmosdb`

### Cross-Subscription Validation Errors

**Cause**: Missing prerequisites for cross-subscription DNS

**Check**:
1. DNS Subscription ID is correct
2. Private DNS Zones exist in DNS subscription
3. VNet peering is established
4. Service principal has "Private DNS Zone Contributor" role

### Generated Module Paths Incorrect

**Cause**: Module source paths are relative to the generated project directory

**Expected**: Source paths are `../../modules/private-dns-{registration|standalone}`

**Note**: This assumes the standard directory structure:
```
.
├── modules/
│   ├── private-dns-registration/
│   └── private-dns-standalone/
└── projects/
    └── myproject-dev/
        └── main.tf  (references ../../modules/...)
```

## Additional Resources

- [PRIVATE_DNS_IMPLEMENTATION.md](PRIVATE_DNS_IMPLEMENTATION.md) - Complete Private DNS overview
- [modules/PRIVATE_DNS_README.md](modules/PRIVATE_DNS_README.md) - Module documentation
- [modules/PRIVATE_DNS_QUICKREF.md](modules/PRIVATE_DNS_QUICKREF.md) - Quick reference
- [templates/VNET_PEERING_MANUAL.md](templates/VNET_PEERING_MANUAL.md) - VNet peering setup
