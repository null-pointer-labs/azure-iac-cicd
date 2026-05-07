# Private DNS Modules - Service-Agnostic DNS Management for Private Endpoints

## Overview

This directory contains **service-agnostic** Terraform modules for managing Private DNS registration for Azure Private Endpoints. These modules are designed to be reusable across ANY Azure service that requires a Private Endpoint (ACR, Key Vault, CosmosDB, Storage, ServiceBus, etc.).

## Architecture

```
modules/
├── private-dns-registration/    # Cross-subscription: Uses existing DNS Zone
│   ├── main.tf                  # References existing zone, creates A record only
│   ├── variables.tf
│   └── outputs.tf
│
└── private-dns-standalone/      # Same-subscription: Creates complete DNS setup
    ├── main.tf                  # Creates DNS Zone + VNet Link + A record
    ├── variables.tf
    └── outputs.tf
```

## Core Concepts

### 1. Service-Agnostic Design

These modules are **NOT tied to any specific Azure service**. Instead:

- Any service module (ACR, KeyVault, CosmosDB, etc.) creates its own Private Endpoint
- The service module extracts the Private Endpoint's private IP
- The service module calls one of these DNS modules based on the `use_existing_private_dns` flag
- The calling module passes the correct `privatelink` DNS zone name for that service

### 2. Two Deployment Scenarios

#### Scenario 1: Cross-Subscription DNS (Existing DNS Zone)
**Module:** `private-dns-registration`

Use when:
- Organization has centralized DNS management
- Private DNS Zones exist in a separate DNS/Hub subscription
- Hub-spoke network architecture is in place
- Multiple subscriptions share DNS zones

What it does:
- ✅ References existing Private DNS Zone via data source
- ✅ Creates DNS A record pointing to Private Endpoint IP
- ❌ Does NOT create DNS Zone (assumes pre-existing)
- ❌ Does NOT create VNet Link (assumes pre-existing)

Requirements:
- Provider alias `azurerm.dns_sub` configured
- VNet peering between workload VNet and DNS hub VNet (manual setup)
- RBAC: "Private DNS Zone Contributor" in DNS subscription

#### Scenario 2: Standalone DNS (Create New DNS Zone)
**Module:** `private-dns-standalone`

Use when:
- Single subscription deployment
- Isolated environment (dev/test)
- Simpler setup preferred
- No existing DNS hub infrastructure

What it does:
- ✅ Creates new Private DNS Zone
- ✅ Creates VNet Link between zone and service VNet
- ✅ Creates DNS A record pointing to Private Endpoint IP

Requirements:
- Default `azurerm` provider only
- No VNet peering needed (all resources in same subscription)

## Usage Pattern

### Step 1: Service Module Creates Private Endpoint

Example: ACR module (`modules/azure-acr/main.tf`)

```hcl
# ACR resource
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"
  # ... other ACR config
}

# Private Endpoint for ACR (no private_dns_zone_group)
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-${var.acr_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-${var.acr_name}"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}

# Output the Private Endpoint's private IP
output "pe_private_ip" {
  description = "Private IP address of the ACR Private Endpoint"
  value       = azurerm_private_endpoint.acr_pe.private_service_connection[0].private_ip_address
}
```

### Step 2: Root Module Calls DNS Module Based on Flag

Example: Root `main.tf`

```hcl
# Call ACR module
module "acr" {
  source = "./modules/azure-acr"
  
  acr_name                    = var.acr_name
  resource_group_name         = azurerm_resource_group.main.name
  location                    = var.location
  pe_subnet_id                = azurerm_subnet.pe.id
  acr_enable_private_endpoint = var.acr_enable_private_endpoint
}

# DNS registration: Cross-subscription (existing DNS zone)
module "acr_dns_existing" {
  count  = var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "./modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.acr.pe_private_ip
  dns_zone_name       = "privatelink.azurecr.io"
  record_name         = var.acr_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

# DNS registration: Standalone (create new DNS zone)
module "acr_dns_standalone" {
  count  = !var.use_existing_private_dns && var.acr_enable_private_endpoint ? 0 : 1
  source = "./modules/private-dns-standalone"

  private_ip_address = module.acr.pe_private_ip
  dns_zone_name      = "privatelink.azurecr.io"
  record_name        = var.acr_name
  dns_zone_rg        = azurerm_resource_group.main.name
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}
```

## Variables

### Root Level Variables

```hcl
variable "use_existing_private_dns" {
  description = "Use existing Private DNS Zones in separate subscription (true) or create standalone zones (false)"
  type        = bool
  default     = false
}

# Required when use_existing_private_dns = true
variable "dns_subscription_id" {
  description = "Subscription ID where Private DNS Zones exist"
  type        = string
  default     = ""
}

variable "dns_zone_rg" {
  description = "Resource Group for DNS Zones (in DNS subscription if cross-sub, or workload subscription if standalone)"
  type        = string
}
```

### Module-Specific Variables

See individual module documentation:
- [private-dns-registration/variables.tf](private-dns-registration/variables.tf)
- [private-dns-standalone/variables.tf](private-dns-standalone/variables.tf)

## Common Private DNS Zone Names by Service

| Azure Service | Private DNS Zone Name |
|---------------|----------------------|
| Azure Container Registry (ACR) | `privatelink.azurecr.io` |
| Azure Key Vault | `privatelink.vaultcore.azure.net` |
| Cosmos DB (MongoDB) | `privatelink.mongo.cosmos.azure.com` |
| Cosmos DB (SQL API) | `privatelink.documents.azure.com` |
| Storage Blob | `privatelink.blob.core.windows.net` |
| Storage File | `privatelink.file.core.windows.net` |
| Storage Queue | `privatelink.queue.core.windows.net` |
| Storage Table | `privatelink.table.core.windows.net` |
| Service Bus | `privatelink.servicebus.windows.net` |
| Event Hubs | `privatelink.servicebus.windows.net` |
| SQL Database | `privatelink.database.windows.net` |
| PostgreSQL | `privatelink.postgres.database.azure.com` |
| MySQL | `privatelink.mysql.database.azure.com` |
| Redis Cache | `privatelink.redis.cache.windows.net` |
| App Service | `privatelink.azurewebsites.net` |
| Cognitive Services | `privatelink.cognitiveservices.azure.com` |

## Provider Configuration

### Cross-Subscription Scenario

Required in `providers.tf`:

```hcl
# Default provider: Workload subscription
provider "azurerm" {
  subscription_id = var.workload_subscription_id
  tenant_id       = var.tenant_id
  features {}
}

# DNS subscription provider alias
provider "azurerm" {
  alias           = "dns_sub"
  subscription_id = var.dns_subscription_id
  tenant_id       = var.tenant_id
  features {}
}
```

### Standalone Scenario

Only default provider needed:

```hcl
provider "azurerm" {
  subscription_id = var.workload_subscription_id
  tenant_id       = var.tenant_id
  features {}
}
```

## Examples

See complete examples in:
- [terraform.tfvars.example](../terraform.tfvars.example) - Configuration examples for both scenarios
- [providers.tf.example](../providers.tf.example) - Provider configuration patterns

## VNet Peering (Cross-Subscription Only)

⚠️ **IMPORTANT**: VNet peering is **intentionally NOT automated** by these modules.

When `use_existing_private_dns = true`, you must manually establish VNet peering between:
- Workload VNet (where Private Endpoints are deployed)
- DNS Hub VNet (where Private DNS Zone is linked)

See [VNET_PEERING_MANUAL.md](../VNET_PEERING_MANUAL.md) for:
- Why peering is not automated
- Prerequisites checklist
- Manual setup instructions (Portal, CLI, separate Terraform)
- Verification steps
- Troubleshooting guide

## Adding Support for New Services

To add Private Endpoint DNS support for a new service:

1. **Create service module** (e.g., `modules/azure-myservice/`)
   - Create the service resource
   - Create Private Endpoint (no `private_dns_zone_group`)
   - Output the Private Endpoint's private IP

2. **Call DNS module from root** (`main.tf`)
   ```hcl
   module "myservice_dns_existing" {
     count  = var.use_existing_private_dns && var.myservice_enable_pe ? 1 : 0
     source = "./modules/private-dns-registration"
     
     providers = {
       azurerm.dns_sub = azurerm.dns_sub
     }
     
     private_ip_address  = module.myservice.pe_private_ip
     dns_zone_name       = "privatelink.myservice.azure.com"  # Service-specific
     record_name         = var.myservice_name
     dns_zone_rg         = var.dns_zone_rg
     dns_subscription_id = var.dns_subscription_id
   }
   
   module "myservice_dns_standalone" {
     count  = !var.use_existing_private_dns && var.myservice_enable_pe ? 1 : 0
     source = "./modules/private-dns-standalone"
     
     private_ip_address = module.myservice.pe_private_ip
     dns_zone_name      = "privatelink.myservice.azure.com"  # Service-specific
     record_name        = var.myservice_name
     dns_zone_rg        = azurerm_resource_group.main.name
     vnet_id            = azurerm_virtual_network.main.id
   }
   ```

3. **No changes to DNS modules required** - they are service-agnostic!

## Best Practices

1. **Consistent Flag Usage**: Set `use_existing_private_dns` once at the root level and apply it consistently across all services

2. **Zone Naming**: Always use the correct `privatelink.*` zone name for each service (see table above)

3. **Resource Naming**: Use descriptive record names (typically the service resource name without special characters)

4. **Tags**: Pass consistent tags from root level to DNS modules

5. **Error Handling**: Handle cases where Private Endpoint is disabled (`acr_enable_private_endpoint = false`) by using conditional module calls with `count`

6. **Testing**: Test both scenarios:
   - Deploy with `use_existing_private_dns = false` first (simpler)
   - Once working, switch to `use_existing_private_dns = true` if needed

7. **Documentation**: Document which `privatelink` zone each service requires in service module documentation

## Troubleshooting

### DNS Resolution Fails

**Symptoms**: Can't resolve `myservice.privatelink.*.azure.com`

**Check**:
1. DNS A record exists in Private DNS Zone
2. VNet Link exists (standalone) or VNet peering established (cross-sub)
3. Private Endpoint has correct subresource name
4. NSG not blocking UDP 53 (DNS)

### Cross-Subscription Access Denied

**Symptoms**: `Error: authorization failed` when creating DNS records

**Check**:
1. `azurerm.dns_sub` provider configured correctly
2. Service principal has "Private DNS Zone Contributor" role in DNS subscription
3. `dns_subscription_id` variable is correct
4. Authentication credentials have access to both subscriptions

### VNet Link Already Exists Error

**Symptoms**: `Error: A resource with the ID ... already exists` (standalone mode)

**Cause**: VNet Link names must be unique per zone

**Solution**: Adjust `vnet_link_name` in `private-dns-standalone` module or use existing DNS zone (cross-sub mode)

### Private Endpoint Works Locally But Not Across Peering

**Symptoms**: DNS resolves from local VNet but not from hub or other spokes

**Check**:
1. VNet peering `allow_forwarded_traffic = true` on both sides
2. Route tables not dropping traffic
3. Azure Firewall not blocking connectivity
4. DNS Zone has VNet Link to hub VNet (not spoke)

## Security Considerations

1. **RBAC Least Privilege**: 
   - Grant only "Private DNS Zone Contributor" for DNS operations
   - Avoid using "Contributor" or "Owner" roles

2. **Network Isolation**:
   - Private Endpoints enforce network-level isolation
   - Disable public endpoints on services when using Private Endpoints

3. **DNS Security**:
   - Private DNS Zones prevent DNS hijacking
   - A records are only visible to linked VNets

4. **Cross-Subscription Boundaries**:
   - Use service principals with minimal cross-subscription permissions
   - Audit cross-subscription access regularly

## Cost Considerations

### Private DNS Zones
- **Cost**: $0.50 per hosted zone per month
- **DNS Queries**: First 1 billion queries/month included

### VNet Peering (Cross-Subscription)
- **Ingress**: ~$0.01 per GB
- **Egress**: ~$0.01 per GB
- **DNS Traffic**: Minimal (<1 MB/day per service)

### Private Endpoints
- **Cost**: $0.01 per hour per endpoint (~$7.30/month)
- **Data Processing**: First 1 GB free, then $0.01 per GB

**Recommendation**: Use standalone mode for dev/test to save on VNet peering costs. Use cross-subscription mode for production with centralized DNS governance.

## References

- [Azure Private Link Documentation](https://learn.microsoft.com/en-us/azure/private-link/)
- [Azure Private DNS Zones](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview)
- [VNet Peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
- [Private Endpoint DNS Integration](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section above
2. Review [VNET_PEERING_MANUAL.md](../VNET_PEERING_MANUAL.md) for peering issues
3. Consult [terraform.tfvars.example](../terraform.tfvars.example) for configuration examples
4. Review Azure Private Link documentation

## License

This module structure follows Terraform best practices and is designed to be reusable across projects.
