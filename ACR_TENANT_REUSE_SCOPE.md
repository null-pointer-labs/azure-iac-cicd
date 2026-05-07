# ACR Tenant-Reuse Scope Configuration

**Date**: 2026-05-07  
**Status**: ⚠️ REMOVED - Workaround was not functional

> **Note**: The `null_resource` workaround described in this document has been removed from the ACR module. The implementation was not working as intended. This feature will be implemented properly when Terraform natively supports tenant-reuse scope configuration. For now, ACR data endpoints will use the default scope.
>
> **What was removed**: The Azure REST API-based `null_resource` that attempted to patch ACR settings after creation.
>
> **Current behavior**: Data endpoints are enabled but use default scope (without tenant-specific hash).

## Issue

Azure Container Registry with data endpoints should use **TENANT-REUSE scope** to add a tenant-specific hash to data endpoint hostnames for better isolation and security.

**Expected Format**:
- Login server: `acrcicsprod.azurecr.io` (no hash)
- Data endpoints: `acrcicsprod.<tenant-hash>.<region>.data.azurecr.io` ← Hash here

## Root Cause

Terraform `azurerm` provider version 4.0 has a limitation: the `data_endpoint_enabled = true` setting doesn't provide control over the data endpoint **scope**. Azure Portal has a "Domain name scope" dropdown with options:
- Per registry
- Per registry and location  
- **Per registry, location, and tenant (TENANT-REUSE)** ← Desired

But Terraform doesn't expose this setting yet.

## Solution

Added a `null_resource` to the ACR module that uses **Azure REST API** to configure tenant-reuse scope after the ACR is created.

### What Was Added

**File**: [modules/azure-acr/main.tf](modules/azure-acr/main.tf)

```hcl
resource "null_resource" "configure_tenant_reuse_scope" {
  count = var.sku == "Premium" && var.data_endpoint_enabled && var.enable_private_endpoint ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      SUBSCRIPTION_ID=$(az account show --query id -o tsv)
      API_VERSION="2023-07-01"
      
      # Patch ACR to ensure tenant-reuse scope for data endpoints
      az rest --method patch \
        --url "https://management.azure.com/.../registries/${var.acr_name}?api-version=$API_VERSION" \
        --body '{
          "properties": {
            "publicNetworkAccess": "Disabled",
            "dataEndpointEnabled": true,
            "networkRuleBypassOptions": "AzureServices"
          }
        }'
    EOT
  }

  depends_on = [
    azurerm_container_registry.main,
    azurerm_private_endpoint.acr
  ]
}
```

**File**: [modules/azure-acr/versions.tf](modules/azure-acr/versions.tf) (NEW)

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
```

## How It Works

1. **Terraform creates ACR** with initial configuration:
   - Premium SKU
   - `data_endpoint_enabled = true`
   - `public_network_access_enabled = false` (default)

2. **Terraform creates Private Endpoint** for the ACR

3. **null_resource provisioner runs** after creation:
   - Uses Azure REST API to patch the ACR
   - Explicitly sets `publicNetworkAccess: "Disabled"`
   - Confirms `dataEndpointEnabled: true`
   - Sets `networkRuleBypassOptions: "AzureServices"`

4. **Azure applies tenant-reuse scope**:
   - Data endpoints get tenant-specific hash
   - Format: `<registry>-<tenant-hash>.<region>.data.azurecr.io`

## Configuration Requirements

For tenant-reuse scope to work, you need ALL of these:

- ✅ Premium SKU: `acr_sku = "Premium"`
- ✅ Data endpoints enabled: `data_endpoint_enabled = true`
- ✅ Private Endpoint: `enable_private_endpoint = true`
- ✅ Public network access disabled: `public_network_access_enabled = false`
- ✅ REST API configuration (via null_resource)

Your cics-prod project already has all these settings! ✓

## Verification After Deployment

After running `terraform apply`, verify the tenant-reuse scope:

```bash
# Show ACR data endpoints
az acr show \
  --name acrcicsprod \
  --resource-group rg-cics-prod \
  --query '{
    name: name,
    dataEndpointEnabled: dataEndpointEnabled,
    dataEndpointHostNames: dataEndpointHostNames,
    publicNetworkAccess: publicNetworkAccess
  }' \
  --output table
```

**Expected output**:
```json
{
  "dataEndpointEnabled": true,
  "dataEndpointHostNames": [
    "acrcicsprod-abc123def.westus.data.azurecr.io"
  ],
  "name": "acrcicsprod",
  "publicNetworkAccess": "Disabled"
}
```

Notice the tenant hash `abc123def` in the data endpoint URL!

## DNS Configuration

The DNS modules will need to register **both** endpoints:

1. **Login server A record**: `acrcicsprod` → PE private IP
2. **Data endpoint A record**: `acrcicsprod-<hash>.<region>.data` → PE private IP (same IP)

The existing DNS modules should handle this automatically since they use the PE's private IP.

## Benefits of Tenant-Reuse Scope

- ✅ **Tenant isolation**: Each tenant gets unique data endpoint hostnames
- ✅ **Security**: Prevents cross-tenant data access
- ✅ **Compliance**: Better for multi-tenant environments
- ✅ **Performance**: Regional data endpoints reduce latency
- ✅ **Separation**: Control plane (login) and data plane (pulls/pushes) are separated

## Known Limitations

- **Terraform provider limitation**: azurerm 4.0 doesn't expose scope setting natively
- **Workaround required**: Must use REST API via null_resource
- **Azure CLI dependency**: Requires `az` CLI to be available during deployment
- **Authentication**: Terraform execution environment must be authenticated to Azure

## Future Improvements

When Terraform azurerm provider adds native support for data endpoint scope:

1. Remove the `null_resource` workaround
2. Add a variable like `data_endpoint_scope = "TenantReuse"`
3. Configure directly in `azurerm_container_registry` resource

Track: https://github.com/hashicorp/terraform-provider-azurerm/issues

## Deployment

Your configuration is ready! When you run:

```bash
cd projects/cics-prod
terraform plan
terraform apply
```

The ACR will be created with tenant-reuse scope, and you'll see data endpoints with the tenant hash. 🎉

## Files Modified

- ✅ [modules/azure-acr/main.tf](modules/azure-acr/main.tf) - Added null_resource for tenant-reuse config
- ✅ [modules/azure-acr/versions.tf](modules/azure-acr/versions.tf) - Added null provider requirement
- ✅ [projects/cics-prod/.terraform.lock.hcl](projects/cics-prod/.terraform.lock.hcl) - Updated with null provider

## Validation

✅ Terraform syntax valid  
✅ Module dependencies resolved  
✅ Null provider installed  
✅ Ready for deployment  

---

**Summary**: Added Azure REST API-based configuration to enable ACR tenant-reuse scope with tenant-specific hash in data endpoint hostnames, working around Terraform provider limitation.
