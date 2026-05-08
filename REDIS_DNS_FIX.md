# Redis Private DNS Zone Fix

## Issue Summary

Redis was creating its own Private DNS zone (`privatelink.redis.cache.windows.net`) instead of using the centralized DNS registration/standalone modules like the other services (ACR, KeyVault, CosmosDB).

## Root Causes

1. **Redis module had embedded DNS logic**: The `modules/azure-redis/main.tf` contained resources to create:
   - Private DNS Zone (`azurerm_private_dns_zone.redis`)
   - VNet Link (`azurerm_private_dns_zone_virtual_network_link.redis`)
   - DNS A Record (`azurerm_private_dns_a_record.redis`)

2. **Scaffold script didn't generate DNS modules for Redis**: The `tf-scaffold.sh` script's `add_private_dns_modules()` function was missing Redis DNS module generation logic

3. **Redis not included in PE detection**: The case statements checking for PE-enabled modules didn't include `azure-redis`

4. **Inconsistent output naming**: Redis module used `private_endpoint_ip` instead of `pe_private_ip` like other modules

## Changes Made

### 1. Redis Module (`modules/azure-redis/`)

#### `main.tf`
- **Removed**: DNS Zone, VNet Link, and A Record resources (lines 100-136)
- **Kept**: Private Endpoint resource (still creates PE)

#### `outputs.tf`
- **Renamed**: `private_endpoint_ip` → `pe_private_ip` for consistency with other modules
- **Removed**: `private_dns_zone_id` output (no longer creating DNS zone)

### 2. Scaffold Script (`tf-scaffold.sh`)

#### Updated `add_private_dns_modules()` function:
- Added `azure-redis` to PE detection case statement
- Added Redis DNS module generation logic (both existing and standalone modes)
  ```bash
  module "redis_dns_existing" {
    count  = var.use_existing_private_dns && var.redis_enable_private_endpoint ? 1 : 0
    source = "../../modules/private-dns-registration"
    
    providers = {
      azurerm.dns_sub = azurerm.dns_sub
    }
    
    private_ip_address  = module.redis_cache.pe_private_ip
    dns_zone_name       = "privatelink.redis.cache.windows.net"
    record_name         = var.redis_name
    dns_zone_rg         = var.dns_zone_rg
    dns_subscription_id = var.dns_subscription_id
    tags                = var.tags
  }
  ```

#### Updated `add_private_dns_variables()` function:
- Added `azure-redis` to PE detection case statement

#### Updated `add_private_dns_tfvars()` function:
- Added `azure-redis` to PE detection case statement

## How to Fix Existing Projects

### Option 1: Regenerate the Project (Recommended)

1. **Backup your current configuration** (if you have customizations):
   ```bash
   cp -r projects/egubifullcics-dev projects/egubifullcics-dev.backup
   ```

2. **Delete the old project**:
   ```bash
   rm -rf projects/egubifullcics-dev
   ```

3. **Regenerate using the updated scaffold**:
   ```bash
   ./tf-scaffold.sh
   # Select same options: egubifullcics, dev, modules (including Redis), DNS mode
   ```

4. **Initialize and plan**:
   ```bash
   cd projects/egubifullcics-dev
   terraform init
   terraform plan
   ```

5. **Expected changes in plan**:
   - **Destroy**: `azurerm_private_dns_zone.redis`, `azurerm_private_dns_zone_virtual_network_link.redis`, `azurerm_private_dns_a_record.redis`
   - **Create**: New DNS module resources (either in existing DNS zone or standalone)

### Option 2: Manual Update (If You Have Customizations)

If you've made custom changes to the project that you want to preserve:

1. **Add the Redis DNS module** to `main.tf` (at the end, after Cosmos DB DNS module):

   ```hcl
   # Azure Redis Cache - Private DNS
   module "redis_dns_existing" {
     count  = var.use_existing_private_dns && var.redis_enable_private_endpoint ? 1 : 0
     source = "../../modules/private-dns-registration"

     providers = {
       azurerm.dns_sub = azurerm.dns_sub
     }

     private_ip_address  = module.redis_cache.pe_private_ip
     dns_zone_name       = "privatelink.redis.cache.windows.net"
     record_name         = var.redis_name
     dns_zone_rg         = var.dns_zone_rg
     dns_subscription_id = var.dns_subscription_id
     tags                = var.tags
   }
   ```

   Or, if using standalone mode:

   ```hcl
   # Azure Redis Cache - Private DNS
   module "redis_dns_standalone" {
     count  = !var.use_existing_private_dns && var.redis_enable_private_endpoint ? 1 : 0
     source = "../../modules/private-dns-standalone"

     private_ip_address = module.redis_cache.pe_private_ip
     dns_zone_name      = "privatelink.redis.cache.windows.net"
     record_name        = var.redis_name
     dns_zone_rg        = var.dns_zone_rg
     vnet_id            = azurerm_virtual_network.main.id
     location           = var.location
     tags               = var.tags
   }
   ```

2. **Run Terraform**:
   ```bash
   cd projects/egubifullcics-dev
   terraform init
   terraform plan
   terraform apply
   ```

## Verification

After applying the fix, verify:

1. **DNS Zone location**:
   - **Existing mode**: Check that A record exists in your existing DNS zone in the DNS subscription
   - **Standalone mode**: Check that new DNS zone was created in workload subscription

2. **Private Endpoint connectivity**: Test that Redis is accessible via its private endpoint

3. **DNS resolution**: Verify that the Redis hostname resolves to the private IP

## Benefits

✅ **Consistent architecture**: Redis now uses the same DNS pattern as ACR, KeyVault, and CosmosDB

✅ **Flexible DNS modes**: Supports both existing DNS zones (cross-subscription) and standalone zones

✅ **Centralized DNS management**: All DNS logic is in reusable modules

✅ **Easier maintenance**: DNS changes only need to be made in one place

## Related Documentation

- [PRIVATE_DNS_IMPLEMENTATION.md](PRIVATE_DNS_IMPLEMENTATION.md) - Complete Private DNS solution overview
- [SCAFFOLD_PRIVATE_DNS.md](SCAFFOLD_PRIVATE_DNS.md) - Scaffold integration guide  
- [modules/PRIVATE_DNS_README.md](modules/PRIVATE_DNS_README.md) - DNS module documentation
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Adding PE support for new services
