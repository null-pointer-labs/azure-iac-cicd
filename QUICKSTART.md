# Quick Start Guide

## Prerequisites

```bash
# Check versions
terraform version  # >= 1.5.0
az version         # >= 2.50.0
```

## 1. Create Backend Storage Account

```bash
# Variables
MGMT_SUB_ID="your-management-subscription-id"
WORKLOAD_SUB_ID="your-workload-subscription-id"
TENANT_ID="your-tenant-id"
RG_NAME="rg-tfstate-mgmt"
SA_NAME="sttfstatemgmt001"  # Must be globally unique
LOCATION="southeastasia"

# Set subscription
az account set --subscription "$MGMT_SUB_ID"

# Create resource group
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION"

# Create storage account
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Create container
az storage container create \
  --name tfstate \
  --account-name "$SA_NAME" \
  --auth-mode login

# Grant yourself permissions
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$MGMT_SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$SA_NAME/blobServices/default/containers/tfstate"
```

See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed explanation.

## 2. Generate SSH Key (if needed)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_vm_key
```

## 3. Create Environment with Scaffold

```bash
# Copy .env template
cp .env.example .env

# Edit .env with your values
nano .env
```

**.env example**:
```bash
WORKLOAD_SUBSCRIPTION_ID="your-workload-sub-id"
TENANT_ID="your-tenant-id"
LOCATION="southeastasia"
BACKEND_SUBSCRIPTION_ID="your-mgmt-sub-id"
BACKEND_RESOURCE_GROUP="rg-tfstate-mgmt"
BACKEND_STORAGE_ACCOUNT="sttfstatemgmt001"
BACKEND_CONTAINER="tfstate"
```

**Run scaffold**:
```bash
./tf-scaffold.sh
```

Select:
- Project name: `myapp`
- Environment: `dev`
- Modules: `1 3` (e.g., ACR + KeyVault)

## 4. Deploy

```bash
# Navigate to generated project
cd projects/myapp-dev

# Review backend config (auto-generated from .env)
cat backend.hcl

# Initialize
terraform init -backend-config=backend.hcl

# Review changes
terraform plan

# Deploy
terraform apply

# View outputs
terraform output
```

## 5. Common Operations

**Add SSH key to tfvars** (if using VMs):
```bash
echo "ssh_public_key = \"$(cat ~/.ssh/azure_vm_key.pub)\"" >> terraform.tfvars
```

**Switch subscriptions**:
```bash
az account set --subscription "$WORKLOAD_SUB_ID"
```

**Destroy environment**:
```bash
terraform destroy
```

**Create additional environment**:
```bash
./tf-scaffold.sh
# Select different environment name (e.g., 'uat')
```

## Troubleshooting

**Error: Failed to get existing workspaces**
```bash
# Grant RBAC on state container
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$MGMT_SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$SA_NAME/blobServices/default/containers/tfstate"
```

**Error: Subscription() could not be determined**
```bash
az account set --subscription "$WORKLOAD_SUB_ID"
```

**Stale state lock**
```bash
terraform force-unlock <lock-id>
```

## Documentation

- [BACKEND_SETUP.md](BACKEND_SETUP.md) - Backend storage concepts and architecture
- [README.md](README.md) - Full project documentation
- [SCAFFOLD_USAGE.md](SCAFFOLD_USAGE.md) - Scaffold script details
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Template/module consistency guide
