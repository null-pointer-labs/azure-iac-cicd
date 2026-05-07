# Private DNS Modules - Quick Reference Guide

## 🎯 Quick Decision: Which Module to Use?

```
┌─────────────────────────────────────────────────────────────────────┐
│ Do you have a centralized DNS/Hub subscription with                 │
│ existing Private DNS Zones?                                         │
│                                                                      │
│  YES → use_existing_private_dns = true                              │
│        → Use private-dns-registration module                        │
│        → Requires VNet peering (manual setup)                       │
│        → Requires azurerm.dns_sub provider alias                    │
│                                                                      │
│  NO  → use_existing_private_dns = false                             │
│        → Use private-dns-standalone module                          │
│        → No VNet peering needed                                     │
│        → Uses default azurerm provider only                         │
└─────────────────────────────────────────────────────────────────────┘
```

## 📁 Module Structure

```
modules/
├── private-dns-registration/     # Cross-sub: References existing DNS Zone
│   ├── main.tf                   # Data source + A record only
│   ├── variables.tf              # Requires dns_subscription_id
│   └── outputs.tf                # DNS record details
│
└── private-dns-standalone/       # Same-sub: Creates DNS Zone
    ├── main.tf                   # DNS Zone + VNet Link + A record
    ├── variables.tf              # Requires vnet_id
    └── outputs.tf                # DNS zone + record details

templates/
├── providers.tf.example          # Shows dual-provider setup
├── terraform.tfvars.example      # Both scenario configurations
└── VNET_PEERING_MANUAL.md        # VNet peering setup guide
```

## 🚀 Quick Start: Standalone Mode (Simplest)

### 1. Set Variables

```hcl
# terraform.tfvars
use_existing_private_dns = false
dns_zone_rg              = "rg-myproject-dev"  # Same RG as service

# Service config
acr_name                    = "myacrdev"
acr_enable_private_endpoint = true
```

### 2. Call DNS Module

```hcl
# main.tf
module "acr_dns_standalone" {
  count  = !var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "./modules/private-dns-standalone"

  private_ip_address = module.acr.pe_private_ip
  dns_zone_name      = "privatelink.azurecr.io"
  record_name        = var.acr_name
  dns_zone_rg        = azurerm_resource_group.main.name
  vnet_id            = azurerm_virtual_network.main.id
  tags               = var.tags
}
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

**Result**: DNS Zone + VNet Link + A record all created automatically!

## 🔄 Quick Start: Cross-Subscription Mode

### 1. Prerequisites

- ✅ Private DNS Zones exist in DNS subscription
- ✅ VNet Links configured to hub VNet
- ✅ VNet peering established (see [VNET_PEERING_MANUAL.md](../templates/VNET_PEERING_MANUAL.md))
- ✅ RBAC: "Private DNS Zone Contributor" in DNS subscription

### 2. Set Variables

```hcl
# terraform.tfvars
use_existing_private_dns = true
dns_subscription_id      = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"
dns_zone_rg              = "rg-dns-hub-prod"  # RG in DNS subscription

# Service config
acr_name                    = "myacrprod"
acr_enable_private_endpoint = true
```

### 3. Configure Providers

```hcl
# providers.tf
provider "azurerm" {
  subscription_id = var.workload_subscription_id
  features {}
}

provider "azurerm" {
  alias           = "dns_sub"
  subscription_id = var.dns_subscription_id
  features {}
}
```

### 4. Call DNS Module

```hcl
# main.tf
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
```

### 5. Deploy

```bash
terraform init
terraform plan
terraform apply
```

**Result**: DNS A record created in existing DNS Zone!

## 📋 Common Private DNS Zones

| Service | DNS Zone |
|---------|----------|
| ACR | `privatelink.azurecr.io` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Cosmos DB (MongoDB) | `privatelink.mongo.cosmos.azure.com` |
| Cosmos DB (SQL) | `privatelink.documents.azure.com` |
| Storage Blob | `privatelink.blob.core.windows.net` |
| Service Bus | `privatelink.servicebus.windows.net` |
| SQL Database | `privatelink.database.windows.net` |
| PostgreSQL | `privatelink.postgres.database.azure.com` |
| Redis | `privatelink.redis.cache.windows.net` |

[Full list →](PRIVATE_DNS_README.md#common-private-dns-zone-names-by-service)

## 🔧 Service Module Pattern

Your service module creates the Private Endpoint and outputs the IP:

```hcl
# modules/azure-myservice/main.tf
resource "azurerm_private_endpoint" "pe" {
  name                = "pe-${var.resource_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-${var.resource_name}"
    private_connection_resource_id = azurerm_MYSERVICE.resource.id
    is_manual_connection           = false
    subresource_names              = ["SUBRESOURCE"]  # e.g., "registry", "vault", etc.
  }
}

# Output for DNS module
output "pe_private_ip" {
  value = azurerm_private_endpoint.pe.private_service_connection[0].private_ip_address
}
```

Root module calls DNS module based on flag (see patterns above).

## 🐛 Troubleshooting Checklist

### DNS Not Resolving

- [ ] DNS A record exists in zone: `az network private-dns record-set a list`
- [ ] VNet Link exists (standalone) or peering established (cross-sub)
- [ ] Test: `nslookup myservice.privatelink.*.azure.com` from VM in VNet
- [ ] Check NSG allows UDP 53

### Cross-Sub Access Denied

- [ ] `dns_subscription_id` variable is correct
- [ ] `azurerm.dns_sub` provider configured
- [ ] Service principal has "Private DNS Zone Contributor" role
- [ ] Auth credentials have access to both subscriptions

### VNet Link Already Exists

- [ ] Check if zone already has VNet Link: `az network private-dns link vnet list`
- [ ] Use unique link names or switch to cross-sub mode

### Module Count Issues

- [ ] Ensure only ONE DNS module is instantiated per service
- [ ] Check: `count = var.use_existing_private_dns ? 1 : 0` logic
- [ ] Verify service PE is enabled: `var.acr_enable_private_endpoint`

## 💰 Cost Summary

| Resource | Cost (USD/month) |
|----------|------------------|
| Private DNS Zone | $0.50 per zone |
| Private Endpoint | ~$7.30 per endpoint |
| VNet Peering Data Transfer | ~$0.01/GB ingress + egress |
| DNS Queries | First 1B/month included |

**Standalone Mode**: Lower cost (no peering data transfer)
**Cross-Sub Mode**: Slightly higher cost (peering), better governance

## 📚 Documentation

- [PRIVATE_DNS_README.md](PRIVATE_DNS_README.md) - Complete module documentation
- [VNET_PEERING_MANUAL.md](../templates/VNET_PEERING_MANUAL.md) - VNet peering setup
- [terraform.tfvars.example](../templates/terraform.tfvars.example) - Configuration examples
- [providers.tf.example](../templates/providers.tf.example) - Provider patterns

## 🎓 Key Concepts

1. **Service-Agnostic**: These modules work with ANY Azure service
2. **Reusable**: Call the same module for ACR, KeyVault, CosmosDB, etc.
3. **Conditional**: Use flags to switch between standalone and cross-sub
4. **Modular**: Service modules focus on their service, DNS modules handle DNS
5. **Manual Peering**: VNet peering is intentionally not automated

## ✅ Validation Steps

After deployment:

```bash
# 1. Check DNS record exists
az network private-dns record-set a show \
  --name myservice \
  --zone-name privatelink.*.azure.com \
  --resource-group DNS_ZONE_RG

# 2. Test DNS resolution from VM in VNet
nslookup myservice.privatelink.*.azure.com

# 3. Test connectivity to private endpoint
curl -v https://myservice.*.azure.com

# 4. Check effective routes (cross-sub only)
az network nic show-effective-route-table \
  --name vm-nic \
  --resource-group RG_NAME
```

## 🆘 Getting Help

1. Review [Troubleshooting](#troubleshooting-checklist) above
2. Check [complete documentation](PRIVATE_DNS_README.md)
3. Verify [provider configuration](../templates/providers.tf.example)
4. Review [VNet peering guide](../templates/VNET_PEERING_MANUAL.md)

---

**Pro Tip**: Start with standalone mode (`use_existing_private_dns = false`) for simplicity. Switch to cross-subscription mode later when you need centralized DNS governance.
