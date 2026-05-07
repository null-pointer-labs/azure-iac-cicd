# Terraform Environment Scaffolder - Usage Guide

## Overview

The `tf-scaffold.sh` script automatically generates new Terraform environments by using the UAT environment as a template. It intelligently substitutes values and filters modules based on your selections.

## Quick Start

**First Time Setup** (recommended):
```bash
# Create .env file from template
cp .env.example .env

# Edit .env with your Azure subscription IDs and tenant ID
nano .env  # or use your preferred editor
```

**Running the Scaffold**:
```bash
./tf-scaffold.sh
```

The script will prompt you for:
1. **Project name** (e.g., `cics`, `komopro`)
2. **Environment name** (e.g., `cics-dev`, `cics-uat`)
3. **Module selection** (numbered list)

**DNS Mode (Automatic)**:
- If your `.env` has `DNS_SUBSCRIPTION_ID` and `DNS_ZONE_RG` → Cross-Subscription DNS mode
- Otherwise → Standalone DNS mode (creates DNS zones in workload subscription)

## Environment Configuration (.env)

The scaffold script supports loading default values from a `.env` file to avoid repetitive data entry.

### What Gets Auto-Populated

When you create a `.env` file, the following values are automatically inserted into generated files:

- **backend.hcl**: subscription_id, tenant_id, resource_group_name, storage_account_name, container_name
- **terraform.tfvars**: workload_subscription_id, tenant_id, location
- **DNS prompts**: Default values for DNS_SUBSCRIPTION_ID and DNS_ZONE_RG (if configured)

### Example .env File

```bash
# Workload Subscription (where resources will be deployed)
WORKLOAD_SUBSCRIPTION_ID="your-workload-subscription-id"
TENANT_ID="your-tenant-id"
LOCATION="Southeast Asia"

# Backend Configuration (where Terraform state is stored)
BACKEND_SUBSCRIPTION_ID="your-workload-subscription-id"
BACKEND_RESOURCE_GROUP="rg-tfstate-mgmt"
BACKEND_STORAGE_ACCOUNT="sttfstatemgmt001"
BACKEND_CONTAINER="tfstate"

# Optional: Cross-Subscription Private DNS
# DNS_SUBSCRIPTION_ID="your-dns-hub-subscription-id"
# DNS_ZONE_RG="rg-dns-hub-prod"
```

### Benefits

✅ **No manual editing** of `backend.hcl` or `terraform.tfvars` after scaffolding  
✅ **Consistent values** across all environments  
✅ **Faster workflow** - no need to look up subscription IDs each time  
✅ **Safe** - `.env` is automatically excluded from version control  

**Note**: If `.env` is not present, the scaffold will use placeholder values (e.g., `TODO-YOUR-WORKLOAD-SUBSCRIPTION-ID`) that you'll need to manually replace.

## Example Usage

```
Terraform Environment Scaffolder

Project name (e.g., cics, komopro):
cics

Environment name (e.g., cics-dev, cics-uat):
cics-dev

Available modules:

  1. azure-acr
  2. azure-aks
  3. azure-cosmosdb
  4. azure-keyvault
  5. azure-redis
  6. azure-vm

Enter module numbers separated by spaces (e.g., 1 3 5), or all to select everything:
1 2 4

✓ Selected modules:
  • azure-acr
  • azure-aks
  • azure-keyvault

Generating configuration from UAT template...
  → Processing main.tf...
  → Processing variables.tf...
  → Processing terraform.tfvars...
  → Processing backend.tf...
  → Copying backend.hcl.example...

✓ Environment scaffolded successfully!

Created files in projects/cics-dev/
  ✓ main.tf (187 lines)
  ✓ variables.tf (95 lines)
  ✓ terraform.tfvars (142 lines)
  ✓ backend.tf (23 lines)
  ✓ backend.hcl.example (12 lines)
```

## Generated Files

### main.tf
- Resource Group, VNet, Subnets
- Selected module blocks (ACR, AKS, Cosmos DB, Key Vault, Redis, VM)
- All "uat" references replaced with your environment name

### variables.tf
- All input variable definitions (copied from UAT)

### terraform.tfvars
- Project configuration (project_name, environment, location)
- Network configuration
- Tags
- **Module-specific variables** (auto-generated from each module's variables.tf)

### backend.tf
- Backend configuration (if exists in UAT)

### Other Files
- `backend.hcl.example` (if exists in UAT)
- `outputs.tf` (if exists in UAT)
- `providers.tf` (if exists in UAT)

## Substitution Rules

| Pattern | Replacement | Example |
|---------|-------------|---------|
| `uat` | `<env-name>` | `uat` → `cics-dev` |
| `UAT` | `<ENV-NAME>` | `UAT` → `CICS-DEV` |
| `rg-*-uat` | `rg-*-<env>` | `rg-komopro-uat` → `rg-komopro-cics-dev` |
| `*-uat-*` | `*-<env>-*` | `vnet-komopro-uat` → `vnet-komopro-cics-dev` |
| `project_name = "komopro"` | `project_name = "cics"` | Based on your input |

## Module Variable Generation

For each selected module, the script:

1. Reads `modules/<module>/variables.tf`
2. Extracts variables with descriptions and defaults
3. Generates tfvars entries with intelligent defaults
4. Skips internal variables (location, resource_group_name, tags, etc.)

### Example Generated tfvars

```hcl
# ===================================================================
# azure-acr Configuration
# ===================================================================

# Name of the Azure Container Registry (must be globally unique, alphanumeric only)
acr_name = "TODO: Name of the Azure Container Registry (must be globally unique, alphanumeric only)"

# SKU tier for the container registry (Basic, Standard, or Premium)
acr_sku = "Premium"

# Enable Private Endpoint for secure access
acr_enable_private_endpoint = true
```

## After Generation

### 1. Review Files

```bash
cd projects/<project-env>
cat terraform.tfvars
```

### 2. Update Configuration

Replace all `TODO:` placeholders in `terraform.tfvars`:
- Resource names (ACR, AKS, Key Vault, etc.)
- Subscription IDs and Tenant IDs
- Network ranges
- SKU sizes

### 3. Configure Backend

```bash
cp backend.hcl.example backend.hcl
# Edit backend.hcl with state storage details
```

### 4. Initialize and Deploy

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Advanced Usage

### Select All Modules

```
Enter module numbers: all
```

### Overwrite Existing Environment

If the directory exists, the script will ask:
```
Warning: Directory 'projects/cics-dev' already exists
Overwrite? (y/N):
```

## Fallback Behavior

If UAT template files are missing:
- **main.tf**: Uses minimal hardcoded template
- **variables.tf**: Uses minimal hardcoded template
- **terraform.tfvars**: Generates from scratch
- Other files: Skipped with warnings

## Troubleshooting

### UAT Template Not Found

Ensure UAT template exists in the projects folder (or use an existing project as template):
```bash
ls projects/myapp-uat/
```

Expected files:
- `main.tf` (required)
- `variables.tf` (required)
- `terraform.tfvars` (recommended)
- `backend.tf` (optional)
- `outputs.tf` (optional)
- `providers.tf` (optional)

### Script Permissions

```bash
chmod +x tf-scaffold.sh
```

### Invalid Environment Name

- Use alphanumeric characters and hyphens only
- Examples: `cics-dev`, `prod`, `analytics-uat`
- Avoid spaces and special characters

## Examples

### Development Environment (Minimal)

```bash
./tf-scaffold.sh
# Project: myapp
# Environment: dev
# Modules: 1 2 (ACR, AKS)
```

### Production (All Services)

```bash
./tf-scaffold.sh
# Project: myapp
# Environment: prod
# Modules: all
```

### Specific Services Only

```bash
./tf-scaffold.sh
# Project: analytics
# Environment: analytics-uat
# Modules: 3 5 (Cosmos DB, Redis)
```

## Best Practices

1. **Keep UAT Updated**: UAT is the template for all new environments
2. **Review Before Applying**: Check generated files for correctness
3. **Version Control**: Commit new environments to git
4. **Consistent Naming**: Use `<project>-<env>` pattern
5. **Document Changes**: Add README in environment directory

## See Also

- **SCAFFOLD_CHANGES.md** - Technical implementation details
- **QUICKSTART.md** - Project overview and architecture
- **README.md** - General project information
