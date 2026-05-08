# Architecture Guide

## Overview

This project uses a **template-based scaffolding system** to generate Terraform environments quickly and consistently. The scaffold script assembles configuration files from reusable templates based on your module selections.

## Project Structure

```
.
├── tf-scaffold.sh              # Scaffold script - generates new environments
├── templates/                  # Template files (assembled into projects)
│   ├── base/                   # Base infrastructure (always included)
│   │   ├── main.tf             # Resource Group, VNet, Subnets
│   │   ├── variables.tf        # Variable definitions
│   │   ├── terraform.tfvars    # Configuration values
│   │   ├── backend.tf          # Backend configuration
│   │   └── providers.tf        # Provider configuration
│   ├── infrastructure/         # Conditional infrastructure (module-specific)
│   │   └── azure-aks-subnet.*  # AKS subnet (only when AKS selected)
│   └── modules/                # Module templates (selectively included)
│       ├── azure-acr/          # Container Registry
│       ├── azure-aks/          # Kubernetes Service
│       ├── azure-cosmosdb/     # Cosmos DB
│       ├── azure-keyvault/     # Key Vault
│       ├── azure-redis/        # Redis Cache
│       └── azure-vm/           # Virtual Machine
├── modules/                    # Actual Terraform modules
│   ├── azure-acr/
│   ├── azure-aks/
│   ├── private-dns-*/          # DNS modules for Private Endpoints
│   └── ...
└── projects/                   # Generated environments (gitignored)
    └── myproject-dev/          # Example generated environment
```

## How the Scaffold Works

### 1. Run the Script

```bash
./tf-scaffold.sh
```

### 2. Interactive Prompts

The script will ask you:

1. **Project name**: e.g., `myproject`
2. **Environment name**: e.g., `myproject-dev`
3. **Module selection**: Choose from available modules

   ```
   Available modules:
     1. azure-acr        (Container Registry)
     2. azure-aks        (Kubernetes)
     3. azure-cosmosdb   (Cosmos DB)
     4. azure-keyvault   (Key Vault)
     5. azure-redis      (Redis Cache)
     6. azure-vm         (Virtual Machine)
   
   Enter module numbers: 1 3 5
   ```

4. **Private DNS mode** (if you selected modules with Private Endpoint support):
   - **Option 1**: Standalone DNS (creates DNS zones in same subscription - simpler)
   - **Option 2**: Cross-Subscription DNS (uses existing DNS zones in hub - enterprise setup)

### 3. File Assembly

The script concatenates template files to create your environment:

```bash
# Assembled files:
projects/myproject-dev/
├── main.tf              # base + selected modules + DNS modules
├── variables.tf         # base + module variables + DNS variables
├── terraform.tfvars     # base + module values + DNS values
├── backend.tf           # backend configuration
├── backend.hcl          # backend credentials (from .env)
└── providers.tf         # providers (+ cross-sub provider if needed)
```

### 4. Value Substitution

Placeholders are replaced with your inputs:

| Placeholder | Example Value |
|-------------|---------------|
| `__PROJECT_NAME__` | `myproject` |
| `__ENV_NAME__` | `myproject-dev` |
| `__DATE__` | `2026-05-08` |

### 5. Ready to Deploy

```bash
cd projects/myproject-dev
terraform init
terraform plan
terraform apply
```

## Networking Architecture

### Base Network (Always Created)

Every environment includes:

```
Resource Group: rg-{project}-{env}
└── Virtual Network: vnet-{project}-{env}
    ├── Subnet: snet-{project}-{env}-default
    │   └── Address: 10.10.1.0/24
    └── Subnet: snet-{project}-{env}-pe
        └── Address: 10.10.2.0/24  (for Private Endpoints)
```

### Module-Specific Subnets

Some modules require dedicated subnets:

| Module | Subnet | Address | Purpose |
|--------|--------|---------|---------|
| AKS | `snet-{project}-{env}-aks` | `10.10.3.0/24` | Kubernetes nodes |

These subnets are **only created when the module is selected**.

### Private Endpoint DNS

Services with Private Endpoints (ACR, Key Vault, Cosmos DB, Redis) support two DNS modes:

**Standalone Mode (Simpler)**:
- Creates Private DNS Zones in the same subscription
- VNet is automatically linked to DNS zones
- No cross-subscription setup needed
- Ideal for: dev/test, single subscription, simple setups

**Cross-Subscription Mode (Enterprise)**:
- Uses existing Private DNS Zones in a hub/DNS subscription
- Requires VNet peering to hub subscription
- Requires RBAC permissions in DNS subscription
- Ideal for: production, multi-subscription, centralized DNS management

## Environment Configuration

### Using .env File (Recommended)

Create a `.env` file to avoid repetitive data entry:

```bash
# Copy template
cp .env.example .env

# Edit with your values
WORKLOAD_SUBSCRIPTION_ID="your-subscription-id"
TENANT_ID="your-tenant-id"
LOCATION="Southeast Asia"

# Backend (where Terraform state is stored)
BACKEND_SUBSCRIPTION_ID="your-backend-subscription-id"
BACKEND_RESOURCE_GROUP="rg-tfstate-mgmt"
BACKEND_STORAGE_ACCOUNT="sttfstatemgmt001"
BACKEND_CONTAINER="tfstate"

# Optional: Cross-Subscription DNS
# DNS_SUBSCRIPTION_ID="your-dns-hub-subscription-id"
# DNS_ZONE_RG="rg-dns-hub-prod"
```

**Benefits**:
- ✅ No manual editing of `backend.hcl` or `terraform.tfvars`
- ✅ Consistent values across all environments
- ✅ Faster workflow
- ✅ Safe - `.env` is gitignored

### Manual Configuration

If you don't use `.env`, you'll need to edit:
- `backend.hcl` - Subscription IDs and storage account details
- `terraform.tfvars` - Workload subscription, location, etc.

## Module Architecture

Each module follows a standard structure:

```
modules/azure-{service}/
├── main.tf              # Service resources + Private Endpoint (if supported)
├── variables.tf         # Input variables
├── outputs.tf           # Outputs (including pe_private_ip for DNS)
└── versions.tf          # Terraform version constraints
```

**Key Points**:
- Modules are reusable across environments
- Private Endpoints are created WITHOUT `private_dns_zone_group` blocks
- DNS registration is handled by separate DNS modules
- Each module outputs `pe_private_ip` for DNS registration

## Best Practices

### When to Use Scaffold

✅ **Use scaffold for**:
- New environments (dev, uat, prod)
- Different projects with similar infrastructure
- Quick prototyping
- Consistent environment setup

❌ **Don't use scaffold for**:
- One-off changes to existing environments (edit files directly)
- Highly customized environments (start with scaffold, then customize)

### Module Selection Guidelines

- **ACR**: If you need container images
- **AKS**: If you need Kubernetes clusters
- **Cosmos DB**: If you need globally distributed databases
- **Key Vault**: Always recommended for secrets management
- **Redis**: If you need caching or session storage
- **VM**: If you need traditional compute (not containers)

### DNS Mode Selection

**Choose Standalone (Option 1) if**:
- Single subscription environment
- Dev/test/sandbox environments
- Simpler management is priority
- No existing DNS infrastructure

**Choose Cross-Subscription (Option 2) if**:
- Enterprise/production environment
- Multiple subscriptions with hub-spoke topology
- Centralized DNS management required
- Existing DNS zones in hub subscription

## Troubleshooting

### Scaffold Issues

**"Module not generating"**:
- Check module exists in `templates/modules/`
- Verify module name in script's `MODULES` array

**"Variables missing"**:
- Ensure module's `variables.tf` template exists
- Check variable names match module inputs

**"DNS modules not appearing"**:
- Only generated for PE-enabled modules (ACR, KeyVault, CosmosDB, Redis)
- Check you selected at least one PE-enabled module

### Deployment Issues

**"Backend initialization failed"**:
- Verify `backend.hcl` values (subscription, resource group, storage account)
- Check you have permissions on storage account
- Run: `az storage container list --account-name {storage-account} --auth-mode login`

**"Private Endpoint DNS not working"**:
- Standalone: Check DNS zone created and VNet link exists
- Cross-sub: Verify VNet peering, RBAC permissions, DNS zones exist

**"Authentication failed"**:
- Run: `az login`
- Verify subscription: `az account show`
- Check RBAC: `az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv)`

## Next Steps

1. **First Time**: See [QUICKSTART.md](QUICKSTART.md) for initial setup
2. **Backend Setup**: See [BACKEND_SETUP.md](BACKEND_SETUP.md) for state storage configuration
3. **Generate Environment**: Run `./tf-scaffold.sh`
4. **Deploy**: `cd projects/{env} && terraform init && terraform apply`

## Additional Resources

- [modules/PRIVATE_DNS_README.md](modules/PRIVATE_DNS_README.md) - Detailed Private DNS module documentation
- [modules/PRIVATE_DNS_QUICKREF.md](modules/PRIVATE_DNS_QUICKREF.md) - Quick reference for DNS setup
- [templates/VNET_PEERING_MANUAL.md](templates/VNET_PEERING_MANUAL.md) - VNet peering setup guide
