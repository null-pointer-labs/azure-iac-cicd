# Private DNS Architecture - Visual Guide

## 🏗️ Overall Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM ROOT MODULE                               │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ Variables:                                                       │ │
│  │ • use_existing_private_dns (bool) - Controls which DNS path      │ │
│  │ • dns_subscription_id (string) - For cross-sub mode             │ │
│  │ • dns_zone_rg (string) - DNS Zone resource group                │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ Service Module (e.g., azure-acr)                               │   │
│  │                                                                 │   │
│  │  1. Creates ACR resource                                       │   │
│  │  2. Creates Private Endpoint                                   │   │
│  │  3. Outputs: pe_private_ip (10.10.2.5)                        │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                          │                                             │
│                          ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ Conditional Logic (based on use_existing_private_dns)          │   │
│  └────────────────────────────────────────────────────────────────┘   │
│         │                                          │                   │
│         │ true                                     │ false             │
│         ▼                                          ▼                   │
│  ┌──────────────────────┐               ┌──────────────────────────┐  │
│  │ private-dns-         │               │ private-dns-standalone   │  │
│  │ registration module  │               │ module                   │  │
│  │                      │               │                          │  │
│  │ • Uses provider:     │               │ • Uses default provider  │  │
│  │   azurerm.dns_sub    │               │ • Creates DNS Zone       │  │
│  │ • References existing│               │ • Creates VNet Link      │  │
│  │   DNS Zone           │               │ • Creates A Record       │  │
│  │ • Creates A Record   │               │                          │  │
│  └──────────────────────┘               └──────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

## 📊 Scenario Comparison

### Scenario 1: Cross-Subscription DNS (Enterprise)

```
┌─────────────────────────────────────────────────────────────────┐
│ DNS SUBSCRIPTION (Centralized)                                  │
│ Subscription ID: zzzz-zzzz-zzzz-zzzz                           │
│                                                                 │
│  ┌────────────────────────────────────────────────┐            │
│  │ Resource Group: rg-dns-hub-prod                │            │
│  │                                                 │            │
│  │  Private DNS Zones (Pre-existing):             │            │
│  │  ┌──────────────────────────────────────────┐  │            │
│  │  │ privatelink.azurecr.io                   │  │            │
│  │  │ ├─ VNet Link → Hub VNet                  │  │            │
│  │  │ └─ A Record: myacr → 10.10.2.5 ◄────────┼──┼───┐        │
│  │  └──────────────────────────────────────────┘  │   │        │
│  │                                                 │   │        │
│  │  ┌──────────────────────────────────────────┐  │   │        │
│  │  │ privatelink.vaultcore.azure.net          │  │   │        │
│  │  │ ├─ VNet Link → Hub VNet                  │  │   │        │
│  │  │ └─ A Record: mykv → 10.10.2.6  ◄─────────┼──┼───┤        │
│  │  └──────────────────────────────────────────┘  │   │        │
│  └────────────────────────────────────────────────┘   │        │
│                                                        │        │
│  ┌────────────────────────────────────────────────┐   │        │
│  │ Hub VNet (10.0.0.0/16)                         │   │        │
│  │ ├─ Firewall                                    │   │        │
│  │ ├─ VPN Gateway                                 │   │        │
│  │ └─ Peered to: Workload VNet                   │   │        │
│  └────────────────────────────────────────────────┘   │        │
└─────────────────────────────────────────────────────────┘        │
                            ▲                                      │
                            │ VNet Peering                         │
                            │ (Manual Setup)                       │
                            │                                      │
┌───────────────────────────┼──────────────────────────────────────┼──┐
│ WORKLOAD SUBSCRIPTION     │                                      │  │
│ Subscription ID: xxxx-xxxx-xxxx-xxxx                             │  │
│                           │                                      │  │
│  ┌────────────────────────┼──────────────────────────────────────┼──┐
│  │ Resource Group: rg-myproject-prod   │                        │  │
│  │                        │             │                        │  │
│  │  Workload VNet (10.10.0.0/16)       │                        │  │
│  │  ├─ Private Endpoint Subnet          │                        │  │
│  │  │  (10.10.2.0/24)                  │                        │  │
│  │  │  ├─ PE-ACR ──────────────────────┘                        │  │
│  │  │  │  Private IP: 10.10.2.5  ──────────────────────────────┘  │
│  │  │  │                                                            │
│  │  │  └─ PE-KeyVault                                              │
│  │  │     Private IP: 10.10.2.6  ───────────────────────────────┘  │
│  │  │                                                                │
│  │  └─ App Subnet (10.10.1.0/24)                                    │
│  │     └─ Applications access PE via private IPs                    │
│  │                                                                   │
│  │  Service Resources:                                              │
│  │  ├─ Azure Container Registry (myacr)                             │
│  │  │  └─ Public access: Disabled                                   │
│  │  └─ Azure Key Vault (mykv)                                       │
│  │     └─ Public access: Disabled                                   │
│  └──────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────┘

Data Flow:
1. App queries: myacr.azurecr.io
2. Azure DNS (168.63.129.16) resolves via Private DNS Zone
3. Returns: 10.10.2.5 (Private Endpoint IP)
4. App connects to ACR via Private Endpoint (within VNet)

Module Used: private-dns-registration
- References existing privatelink.azurecr.io zone in DNS subscription
- Creates A record: myacr → 10.10.2.5
- Requires: azurerm.dns_sub provider alias
```

### Scenario 2: Standalone DNS (Dev/Test/Simple)

```
┌─────────────────────────────────────────────────────────────────┐
│ WORKLOAD SUBSCRIPTION (Single Subscription)                    │
│ Subscription ID: xxxx-xxxx-xxxx-xxxx                           │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐│
│  │ Resource Group: rg-myproject-dev                           ││
│  │                                                             ││
│  │  ┌──────────────────────────────────────────────────────┐  ││
│  │  │ Private DNS Zone: privatelink.azurecr.io             │  ││
│  │  │ (Created by private-dns-standalone module)           │  ││
│  │  │                                                       │  ││
│  │  │ ├─ VNet Link → Workload VNet                         │  ││
│  │  │ └─ A Record: myacrdev → 10.10.2.5                   │  ││
│  │  └──────────────────────────────────────────────────────┘  ││
│  │                            ▲                                ││
│  │                            │ Created by module              ││
│  │                            │                                ││
│  │  Workload VNet (10.10.0.0/16)                              ││
│  │  ├─ Private Endpoint Subnet (10.10.2.0/24)                 ││
│  │  │  └─ PE-ACR                                              ││
│  │  │     Private IP: 10.10.2.5 ──────────────────────────────┘│
│  │  │                                                           │
│  │  └─ App Subnet (10.10.1.0/24)                               │
│  │     └─ Applications access PE via private IP                │
│  │                                                              │
│  │  Service Resources:                                         │
│  │  └─ Azure Container Registry (myacrdev)                     │
│  │     └─ Public access: Disabled                              │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘

Data Flow:
1. App queries: myacrdev.azurecr.io
2. Azure DNS (168.63.129.16) resolves via Private DNS Zone in same VNet
3. Returns: 10.10.2.5 (Private Endpoint IP)
4. App connects to ACR via Private Endpoint (within VNet)

Module Used: private-dns-standalone
- Creates new privatelink.azurecr.io zone in workload subscription
- Creates VNet Link to workload VNet
- Creates A record: myacrdev → 10.10.2.5
- Requires: Only default azurerm provider
```

## 🔄 Module Call Flow

### High-Level Flow

```
┌─────────────┐
│ Root main.tf│
└──────┬──────┘
       │
       ├─► Call Service Module (e.g., azure-acr)
       │   └─► Creates: ACR + Private Endpoint
       │       └─► Output: pe_private_ip = 10.10.2.5
       │
       ├─► Conditional: use_existing_private_dns == true?
       │   │
       │   ├─ YES ─► Call private-dns-registration
       │   │         ├─ Input: pe_private_ip from service module
       │   │         ├─ Input: dns_zone_name = "privatelink.azurecr.io"
       │   │         ├─ Input: record_name = "myacr"
       │   │         └─ Action: Create A record in existing zone
       │   │
       │   └─ NO ──► Call private-dns-standalone
       │             ├─ Input: pe_private_ip from service module
       │             ├─ Input: dns_zone_name = "privatelink.azurecr.io"
       │             ├─ Input: record_name = "myacr"
       │             ├─ Input: vnet_id from root
       │             └─ Action: Create zone + VNet link + A record
       │
       └─► Result: DNS resolution works for Private Endpoint!
```

### Detailed Module Interaction

```
Root Module Variables                 Service Module
┌──────────────────────┐             ┌────────────────────────┐
│ use_existing_        │             │ module "acr"           │
│ private_dns = true   │             │                        │
│                      │             │ Creates:               │
│ dns_subscription_id  │             │ • ACR resource         │
│ dns_zone_rg          │             │ • Private Endpoint     │
│ workload_sub_id      │             │                        │
│ vnet_id              │             │ Outputs:               │
│ tags                 │             │ • pe_private_ip        │
└──────────┬───────────┘             │   = 10.10.2.5          │
           │                         └───────┬────────────────┘
           │                                 │
           │                                 │ Private IP
           │                                 ▼
           │              ┌─────────────────────────────────┐
           │              │ Conditional Module Selection    │
           │              │                                 │
           │              │ count = var.use_existing_       │
           │              │         private_dns ? 1 : 0     │
           │              └──────────┬──────────────────────┘
           │                         │
           ├─────────────────────────┼─────────────────────────┐
           │                         │                         │
           │ true                    │                         │ false
           ▼                         │                         ▼
┌─────────────────────────┐          │          ┌──────────────────────────┐
│ private-dns-registration│          │          │ private-dns-standalone   │
│                         │          │          │                          │
│ Inputs:                 │          │          │ Inputs:                  │
│ • pe_private_ip ◄───────┼──────────┘          │ • pe_private_ip ◄────────┤
│ • dns_zone_name         │                     │ • dns_zone_name          │
│ • record_name           │                     │ • record_name            │
│ • dns_zone_rg ◄─────────┤                     │ • dns_zone_rg ◄──────────┤
│ • dns_subscription_id ◄─┤                     │ • vnet_id ◄──────────────┤
│ • tags ◄────────────────┤                     │ • tags ◄─────────────────┤
│                         │                     │                          │
│ Provider:               │                     │ Provider:                │
│ • azurerm.dns_sub       │                     │ • azurerm (default)      │
│                         │                     │                          │
│ Creates:                │                     │ Creates:                 │
│ • DNS A record          │                     │ • Private DNS Zone       │
│   (in existing zone)    │                     │ • VNet Link              │
│                         │                     │ • DNS A record           │
│                         │                     │                          │
│ Outputs:                │                     │ Outputs:                 │
│ • dns_record_id         │                     │ • dns_zone_id            │
│ • dns_record_fqdn       │                     │ • vnet_link_id           │
│ • dns_zone_id           │                     │ • dns_record_id          │
│ • private_ip_address    │                     │ • dns_record_fqdn        │
└─────────────────────────┘                     └──────────────────────────┘
```

## 🧩 Adding New Service Support

```
Step 1: Create Service Module
┌────────────────────────────────────┐
│ modules/azure-myservice/           │
│ ├── main.tf                        │
│ │   ├── Resource: myservice        │
│ │   └── Resource: private_endpoint │
│ ├── variables.tf                   │
│ └── outputs.tf                     │
│     └── pe_private_ip ◄─────────┐  │
└─────────────────────────────────┼──┘
                                  │
Step 2: Call from Root            │
┌─────────────────────────────────┼──┐
│ main.tf                          │  │
│                                  │  │
│ module "myservice" {             │  │
│   source = "./modules/...        │  │
│   ...                            │  │
│ }                                │  │
│                                  │  │
│ # DNS Registration (existing)    │  │
│ module "myservice_dns_existing" {│  │
│   count  = var.use_existing_...  │  │
│   source = "./modules/           │  │
│            private-dns-          │  │
│            registration"         │  │
│                                  │  │
│   private_ip_address = ──────────┘  │
│     module.myservice.pe_private_ip  │
│   dns_zone_name =                   │
│     "privatelink.myservice..."  ◄───┼─ Service-specific zone name
│   record_name = var.myservice_name  │
│   ...                                │
│ }                                    │
│                                      │
│ # DNS Standalone                     │
│ module "myservice_dns_standalone" {  │
│   count  = !var.use_existing_...     │
│   source = "./modules/               │
│            private-dns-standalone"   │
│   ...                                │
│ }                                    │
└──────────────────────────────────────┘

Step 3: No DNS Module Changes Needed!
The DNS modules are service-agnostic and reusable.
```

## 📐 Decision Matrix

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
┃ Requirement                 ┃ Standalone Mode     ┃ Cross-Sub Mode     ┃
┃                             ┃ (DNS in workload)   ┃ (DNS in hub)       ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━━━━━━┫
┃ Single subscription         ┃ ✅ Perfect fit       ┃ ❌ Unnecessary      ┃
┃ Multiple subscriptions      ┃ ⚠️ Per-sub zones     ┃ ✅ Centralized      ┃
┃ Centralized DNS governance  ┃ ❌ Not supported     ┃ ✅ Required         ┃
┃ Simple setup                ┃ ✅ Very simple       ┃ ⚠️ More complex     ┃
┃ VNet peering required       ┃ ❌ Not needed        ┃ ✅ Manual setup     ┃
┃ Cross-subscription RBAC     ┃ ❌ Not needed        ┃ ✅ Required         ┃
┃ Dev/Test environment        ┃ ✅ Recommended       ┃ ⚠️ Optional         ┃
┃ Production environment      ┃ ⚠️ Depends           ┃ ✅ Recommended      ┃
┃ Cost (DNS zones)            ┃ 💰 Per environment   ┃ 💰💰 Shared zones   ┃
┃ Cost (VNet peering)         ┃ 💰 None              ┃ 💰💰 Data transfer  ┃
┃ Isolation                   ┃ ✅ Full isolation    ┃ ⚠️ Shared DNS       ┃
┃ Module complexity           ┃ ✅ Simple            ┃ ⚠️ Provider alias   ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛

Legend:
✅ Best choice / Optimal
⚠️ Possible / Consider trade-offs
❌ Not applicable / Not recommended
💰 Lower cost
💰💰 Higher cost
```

## 🔐 RBAC Requirements

### Standalone Mode

```
Required Permissions in Workload Subscription:
┌─────────────────────────────────────────────┐
│ Service Principal / Managed Identity        │
│                                             │
│ Role: Contributor (or combination below)    │
│                                             │
│ ├─ Network Contributor                     │
│ │  • Create/manage VNets                   │
│ │  • Create/manage Private Endpoints       │
│ │  • Create/manage Subnets                 │
│ │                                           │
│ └─ Private DNS Zone Contributor             │
│    • Create Private DNS Zones               │
│    • Create VNet Links                      │
│    • Create DNS A records                   │
└─────────────────────────────────────────────┘
```

### Cross-Subscription Mode

```
Required Permissions in TWO Subscriptions:

┌─────────────────────────────────────────────┐
│ Workload Subscription                       │
│                                             │
│ Service Principal / Managed Identity        │
│                                             │
│ Role: Contributor (or specific roles)       │
│                                             │
│ ├─ Network Contributor                     │
│ │  • Create/manage VNets                   │
│ │  • Create/manage Private Endpoints       │
│ │  • Create/manage Subnets                 │
│ │                                           │
│ └─ Contributor (for service resources)      │
│    • Create ACR, KeyVault, CosmosDB, etc.  │
└─────────────────────────────────────────────┘

                    +

┌─────────────────────────────────────────────┐
│ DNS Subscription                            │
│                                             │
│ Service Principal / Managed Identity        │
│                                             │
│ Role: Private DNS Zone Contributor          │
│                                             │
│ └─ Private DNS Zone Contributor             │
│    • Read existing DNS Zones                │
│    • Create DNS A records                   │
│    • (NOT required: create zones/links)     │
└─────────────────────────────────────────────┘

Note: Some organizations use "DNS Zone Contributor" 
      + "Reader" instead of "Private DNS Zone Contributor"
```

## 🎯 Summary

| Aspect | Standalone | Cross-Subscription |
|--------|------------|-------------------|
| **Complexity** | Low | Medium-High |
| **Setup Time** | Minutes | Hours (incl. peering) |
| **Best For** | Dev/Test, Single-sub | Prod, Enterprise |
| **Modules Used** | private-dns-standalone | private-dns-registration |
| **Providers** | 1 (default) | 2 (default + dns_sub) |
| **VNet Peering** | Not required | Required (manual) |
| **DNS Management** | Decentralized | Centralized |
| **Cost Impact** | Lower | Slightly higher |

---

**Recommendation**: Start with **standalone mode** for proof-of-concept. Migrate to **cross-subscription mode** when you need enterprise-grade DNS governance.
