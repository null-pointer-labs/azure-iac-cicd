# Quick Start Guide - Komopro Terraform Project

## 🎯 Cross-Subscription Architecture

```
┌─────────────────────────────────────────────────┐
│     Management Subscription                     │
│  ┌─────────────────────────────────────────┐   │
│  │  Azure Storage Account                  │   │
│  │  - State files for all environments     │   │
│  │  - Azure AD authentication              │   │
│  │  - RBAC: Storage Blob Data Contributor  │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                       ↓
                  State Storage
                       ↓
┌─────────────────────────────────────────────────┐
│     Workload Subscription                       │
│  ┌───────────────────────────────────────────┐ │
│  │  Environment: UAT                         │ │
│  │  - Resource Group: rg-komopro-uat         │ │
│  │  - VNet: vnet-komopro-uat                 │ │
│  │  - VMs: vm-komopro-uat-sys-01, -02        │ │
│  │  - Data Disks: 256 GiB StandardSSD        │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │  Environment: Dev (future)                │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │  Environment: Prod (future)               │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## ⚡ Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] Azure CLI >= 2.50.0 installed
- [ ] Two Azure subscriptions identified:
  - [ ] Management subscription ID
  - [ ] Workload subscription ID
- [ ] Azure AD tenant ID
- [ ] SSH key pair generated (`ssh-keygen -t rsa -b 4096`)

## 🔑 Required RBAC Permissions

### Your Identity Needs:

1. **Management Subscription**:
   - Role: `Storage Blob Data Contributor`
   - Scope: State storage container

2. **Workload Subscription**:
   - Role: `Contributor`
   - Scope: Subscription or resource group level

## 🚀 Deployment Steps

### 1. Authenticate
```bash
az login
az account set --subscription "<workload-subscription-id>"
```

### 2. Configure Backend
Edit `environments/uat/backend.hcl`:
```hcl
resource_group_name  = "no-security"          # Your actual RG
storage_account_name = "egubibackendsa"       # Your actual SA
container_name       = "egubibackendsa"       # Your actual container
key                  = "uat/terraform.tfstate"
subscription_id      = "<MANAGEMENT_SUB_ID>"
tenant_id            = "<TENANT_ID>"
```

### 3. Configure Variables
Edit `environments/uat/terraform.tfvars`:
```hcl
workload_subscription_id = "<WORKLOAD_SUB_ID>"
tenant_id                = "<TENANT_ID>"
ssh_public_key           = "ssh-rsa AAAA..."  # From ~/.ssh/id_rsa.pub
```

### 4. Deploy
```bash
cd environments/uat
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## 📋 What Gets Created

### Networking
- Resource Group: `rg-komopro-uat`
- VNet: `vnet-komopro-uat` (10.10.0.0/16)
- Subnet: `snet-komopro-uat` (10.10.1.0/24)
- NSG: `nsg-komopro-uat` (SSH rule)

### Compute
- **System Node 01**:
  - VM: `vm-komopro-uat-sys-01` (Standard_F4s_v2)
  - NIC: `nic-komopro-uat-sys-01`
  - OS Disk: `osdisk-vm-komopro-uat-sys-01`
  - Data Disk 01: `disk-vm-komopro-uat-sys-01-data01` (256 GiB)
  - Data Disk 02: `disk-vm-komopro-uat-sys-01-data02` (256 GiB)

- **System Node 02**:
  - VM: `vm-komopro-uat-sys-02` (Standard_F4s_v2)
  - NIC: `nic-komopro-uat-sys-02`
  - OS Disk: `osdisk-vm-komopro-uat-sys-02`
  - Data Disk 01: `disk-vm-komopro-uat-sys-02-data01` (256 GiB)
  - Data Disk 02: `disk-vm-komopro-uat-sys-02-data02` (256 GiB)

## 🔍 Outputs
```bash
terraform output

# Returns:
# - system_node_names: ["vm-komopro-uat-sys-01", "vm-komopro-uat-sys-02"]
# - system_node_private_ips: ["10.10.1.4", "10.10.1.5"]
# - resource_group_name: "rg-komopro-uat"
# - vnet_name: "vnet-komopro-uat"
```

## 🔧 Common Operations

### Connect to VM
```bash
# Get private IP
PRIVATE_IP=$(terraform output -json system_node_private_ips | jq -r '.[0]')

# SSH (if using Bastion or VPN)
ssh -i ~/.ssh/azure_vm_key azureuser@$PRIVATE_IP
```

### Scale System Nodes
Edit `terraform.tfvars`:
```hcl
system_node_count = 3  # Change from 2 to 3
```

Apply:
```bash
terraform plan
terraform apply
```

### Add Data Disks
Edit `terraform.tfvars`:
```hcl
system_node_data_disks = [
  {
    name_suffix          = "data01"
    disk_size_gb         = 256
    storage_account_type = "StandardSSD_LRS"
    lun                  = 0
    caching              = "ReadWrite"
  },
  {
    name_suffix          = "data03"        # New disk
    disk_size_gb         = 512             # 512 GiB
    storage_account_type = "Premium_LRS"   # Premium
    lun                  = 2               # Unique LUN
    caching              = "ReadWrite"
  }
]
```

Apply:
```bash
terraform apply
```

### Destroy Environment
```bash
terraform destroy
```

## 🆘 Troubleshooting

### Error: "Failed to get existing workspaces"
**Cause**: Missing RBAC permissions on state storage

**Fix**:
```bash
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<mgmt-sub>/resourceGroups/no-security/providers/Microsoft.Storage/storageAccounts/egubibackendsa/blobServices/default/containers/egubibackendsa"
```

### Error: "Subscription() could not be determined"
**Cause**: Wrong subscription context

**Fix**:
```bash
az account set --subscription "<workload-subscription-id>"
terraform plan
```

### Error: "State lock"
**Cause**: Previous operation didn't complete

**Fix**:
```bash
# Check if another terraform process is running
# If stale lock, break it:
terraform force-unlock <lock-id>
```

## 📖 Next Steps

1. **Restrict SSH Access**: Edit `environments/uat/main.tf`, change NSG rule:
   ```hcl
   source_address_prefix = "YOUR_IP/32"
   ```

2. **Add Dev Environment**:
   ```bash
   cp -r environments/uat environments/dev
   # Edit backend.hcl, terraform.tfvars, variables.tf
   cd environments/dev
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

3. **Enable Monitoring**: Add Azure Monitor, Application Insights

4. **Backup Configuration**: Set up Azure Backup for VMs

5. **Cost Optimization**: Review VM sizes, disk types, and implement auto-shutdown

## 📞 Support

For detailed documentation, see [README.md](README.md)

**Common Commands**:
- Init: `terraform init -backend-config=backend.hcl`
- Plan: `terraform plan`
- Apply: `terraform apply`
- Destroy: `terraform destroy`
- Outputs: `terraform output`
- Format: `terraform fmt -recursive`
- Validate: `terraform validate`
