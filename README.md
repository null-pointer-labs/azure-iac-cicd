# Azure Infrastructure Terraform Project

This repository contains Terraform configurations for deploying Azure infrastructure using a modular, environment-based approach with **cross-subscription state management**. The project separates state storage (management subscription) from workload resources (workload subscription) and uses Azure AD authentication for secure state access.

## � Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get started quickly with your first deployment
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Learn how the scaffolding system works and networking architecture
- **[BACKEND_SETUP.md](BACKEND_SETUP.md)** - Configure Terraform state storage in Azure
- **README.md** (this file) - Complete reference and deployment guide

## �📁 Project Structure

```
.
├── modules/
│   ├── azure-vm/                # Reusable VM module
│   │   ├── main.tf              # VM, NIC, data disks, and Public IP resources
│   │   ├── variables.tf         # Module input variables
│   │   └── outputs.tf           # Module outputs
│   └── azure-acr/               # Reusable ACR module with Private Endpoint
│       ├── main.tf              # ACR, Private Endpoint, Private DNS Zone
│       ├── variables.tf         # Module input variables
│       └── outputs.tf           # Module outputs
├── projects/
│   └── myapp-uat/               # Example project environment
│       ├── main.tf              # Resource Group, VNet, Subnets, and module calls
│       ├── variables.tf         # Environment input variables
│       ├── providers.tf         # Provider and version configuration
│       ├── backend.tf           # Empty backend block (partial backend pattern)
│       ├── backend.hcl          # Actual backend values (DO NOT COMMIT)
│       ├── backend.hcl.example  # Backend configuration template
│       ├── terraform.tfvars     # Environment-specific values
│       └── outputs.tf           # Environment outputs
├── .gitignore                   # Excludes backend.hcl and *.tfvars
└── README.md                    # This file
```

## 🏗️ Architecture Overview

### Cross-Subscription Design

This project uses a **two-subscription architecture**:

1. **Management Subscription**: Hosts Terraform state storage (Azure Storage Account)
2. **Workload Subscription**: Hosts deployed resources (VMs, VNets, etc.)

**Benefits**:
- Centralized state management across multiple workload subscriptions
- Enhanced security through subscription-level isolation
- Separation of concerns (infrastructure state vs. runtime resources)
- Azure AD authentication for state access (no storage keys)

### Per-Environment Resources

Each environment (UAT, Dev, Prod) deploys:
- **Resource Group**: Dedicated resource group for the environment
- **Virtual Network**: Isolated VNet with configurable address space
- **Subnets**:
  - **VM Subnet** (`snet-*-vm`): For virtual machine NICs
  - **Private Endpoint Subnet** (`snet-*-pe`): For PaaS service Private Endpoints (ACR, Storage, etc.)
- **Network Security Group**: Basic security rules (SSH access) attached to VM subnet
- **Virtual Machines**: Multiple Linux VMs using the azure-vm module with data disks
- **Azure Container Registry**: Premium SKU with Private Endpoint for secure image storage

### Networking Architecture

**Design Principle**: Networking is environment-scoped, not module-scoped.

```
Resource Group (per environment)
└── Virtual Network (per environment)
    ├── Subnet: vm-subnet      → used by azure-vm module
    └── Subnet: pe-subnet      → used by PaaS modules (ACR, etc.) for Private Endpoints
```

**Key Concepts**:
- **Environment-scoped resources** (created directly in `projects/<project-env>/main.tf`):
  - Resource Group
  - Virtual Network
  - Subnets (VM subnet, PE subnet)
  - Private DNS Zones (if shared across multiple PaaS services)

- **Module-scoped resources** (created inside `modules/`):
  - The workload itself (VMs, ACR, AKS, Storage, etc.)
  - Tightly-coupled resources (NICs, disks, Private Endpoint for that specific resource)

**Benefits**:
- PaaS modules (ACR, AKS, Storage) can all attach to the same PE subnet
- No VNet/subnet duplication inside modules
- Adding a new PaaS service = create a module that accepts `pe_subnet_id`
- Clean separation between environment-level networking and workload modules

### Module: azure-vm
The `azure-vm` module creates:
- **Network Interface (NIC)**: One per VM, connected to the provided subnet
- **Linux Virtual Machines**: Ubuntu 22.04 LTS with SSH key authentication (configurable count)
- **OS Disk**: Configurable storage type (Standard_LRS by default)
- **Data Disks**: Multiple managed data disks per VM (configurable count, size, and storage type)
- **Public IP**: Optional per VM, controlled via `enable_public_ip` variable

### Module: azure-acr

The `azure-acr` module creates:
- **Azure Container Registry**: Premium SKU for Private Endpoint support
- **Private Endpoint**: Secure, private access to the ACR (no public internet access)
- **Private DNS Zone** (`privatelink.azurecr.io`): DNS resolution for private ACR access
- VM Subnet: `snet-myproject-uat-vm`
- PE Subnet: `snet-myproject-uat-pe`
- Virtual Machine: `vm-myproject-uat-sys-01`, `vm-myproject-uat-sys-02`
- Network Interface: `nic-vm-myproject-uat-sys-01`
- Public IP: `pip-vm-myproject-uat-sys-01`
- Data Disk: `disk-vm-myproject-uat-sys-01-data01`
- Container Registry: `acrkomoprouat` (alphanumeric only)
- Private Endpoint: `pe-acrkomoprouat
### Naming Convention
Resources follow this pattern: `<resource-type>-<project>-<environment>[-role][-number]`

Examples:
- Resource Group: `rg-myproject-uat`
- Virtual Network: `vnet-myproject-uat`
- Subnet: `snet-myproject-uat-default`
- Virtual Machine: `vm-myproject-uat-sys-01`, `vm-myproject-uat-sys-02`
- Network Interface: `nic-vm-myproject-uat-sys-01`
- Public IP: `pip-vm-myproject-uat-sys-01`
- Data Disk: `disk-vm-myproject-uat-sys-01-data01`

## 🚀 Getting Started

### Prerequisites

**Required Tools**:
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50.0
- SSH key pair for VM authentication

**Azure Resources**:
- Two Azure subscriptions (or one subscription with proper access):
  - Management subscription (for state storage)
  - Workload subscription (for resources)
- Azure Storage Account in management subscription for Terraform state
- Appropriate RBAC permissions (see below)

### Required RBAC Permissions

The identity running Terraform (Service Principal, Managed Identity, or User) requires:

#### Management Subscription (State Storage)
- **Storage Blob Data Contributor** role on the state storage container
  - Required for: Reading and writing Terraform state files
  - Scope: Container level (e.g., `/subscriptions/<mgmt-sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<sa-name>/blobServices/default/containers/tfstate`)

#### Workload Subscription (Resource Deployment)
- **Contributor** role (or custom role with appropriate permissions)
  - Required for: Creating/modifying/deleting Azure resources
  - Scope: Subscription level or resource group level

**Grant RBAC using Azure CLI**:
```bash
# Grant Storage Blob Data Contributor on state container
az role assignment create \
  --assignee <service-principal-id or user-object-id> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<mgmt-sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<sa-name>/blobServices/default/containers/tfstate"

# Grant Contributor on workload subscription
az role assignment create \
  --assignee <service-principal-id or user-object-id> \
  --role "Contributor" \
  --scope "/subscriptions/<workload-sub-id>"
```

### Environment Configuration (.env File)

To avoid repeatedly entering subscription IDs, tenant IDs, and backend configuration values, you can create a `.env` file:

1. **Copy the template**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your Azure values**:
   ```bash
   # Workload Subscription (where resources will be deployed)
   WORKLOAD_SUBSCRIPTION_ID="your-workload-subscription-id"
   TENANT_ID="your-azure-tenant-id"
   LOCATION="Southeast Asia"

   # Backend Configuration (where Terraform state is stored)
   BACKEND_SUBSCRIPTION_ID="your-backend-subscription-id"
   BACKEND_RESOURCE_GROUP="rg-tfstate-mgmt"
   BACKEND_STORAGE_ACCOUNT="sttfstatemgmt001"
   BACKEND_CONTAINER="tfstate"

   # Private DNS Configuration (AUTOMATIC DETECTION)
   # Set BOTH values for Cross-Subscription DNS mode
   # Leave empty/commented for Standalone DNS mode
   # DNS_SUBSCRIPTION_ID="your-dns-hub-subscription-id"
   # DNS_ZONE_RG="rg-dns-hub-prod"
   ```

3. **How it works**:
   - When you run `./tf-scaffold.sh`, it automatically loads values from `.env`
   - Generated `backend.hcl` and `terraform.tfvars` are prepopulated with your subscription IDs
   - **DNS mode is automatically detected**: If both DNS values are set → Cross-Subscription mode; otherwise → Standalone mode
   - No manual editing or prompts required after scaffolding
   - `.env` is excluded from version control (`.gitignore`)

**Benefits**:
- ✅ No repetitive data entry across projects
- ✅ Consistent configuration across all environments
- ✅ Quick project setup for new environments
- ✅ Safe - excluded from git by default

### Authentication Options
### Standard Workflow

1. **Navigate to your project directory**
   ```bash
   cd projects/myapp-uat
   ```

2. **Initialize Terraform with Backend Configuration**
   
   **Important**: Unlike standard Terraform init, we use `-backend-config` to supply backend values:
   
   ```bash
   terraform init -backend-config=backend.hcl
   ```
   
   This command:
   - Initializes the working directory
   - Configures the Azure backend using values from `backend.hcl`
   - Downloads required provider plugins
   - Sets up state storage in the management subscription

   **Why partial backend configuration?**
   - Backend blocks cannot reference Terraform variables
   - Allows dynamic backend configuration per environment
   - Keeps sensitive subscription IDs out of `.tf` files

3. **Review the Plan**
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```
   
   Or rely on auto-loading (Terraform automatically loads `terraform.tfvars`):
   ```bash
   terraform plan
   ```
   
   Review the proposed changes carefully before applying.

4. **Apply the Configuration**
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```
   
   Or simply:
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted to confirm.

5. **View Outputs**
   ```bash
   terraform output
   ```
   
   This displays important information like VM names, IPs,
  --location "Southeast Asia" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2

# Create container for state files
az storage container create \
  --name tfstate \
  --account-name sttfstatemgmt001 \
  --auth-mode login

# Grant yourself Storage Blob Data Contributor
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<mgmt-sub-id>/resourceGroups/rg-tfstate-mgmt/providers/Microsoft.Storage/storageAccounts/sttfstatemgmt001/blobServices/default/containers/tfstate"
```

#### 2. Configure Backend Settings

Edit `projects/myapp-uat/backend.hcl` with your actual values:

```hcl
resource_group_name  = "rg-tfstate-mgmt"
storage_account_name = "sttfstatemgmt001"
container_name       = "tfstate"
key                  = "myapp-uat/terraform.tfstate"
subscription_id      = "<MANAGEMENT_SUBSCRIPTION_ID>"
tenant_id            = "<TENANT_ID>"
```

**Important**: Add `backend.hcl` to `.gitignore` (already configured) and never commit it with real values.

#### 3. Generate SSH Key Pair (if needed)
```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/azure_vm_key
```

#### 4. Update terraform.tfvars

Edit `projects/myapp-uat/terraform.tfvars`:
- `workload_subscription_id`: Your workload subscription ID
- `tenant_id`: Your Azure AD tenant ID
- `ssh_public_key`: Contents of `~/.ssh/azure_vm_key.pub`
- `tags`: Update with your organization's values
- Other configuration as needed

## 📝 Deploying the UAT Environment

1. **Navigate to the UAT environment directory**
   ```bash
   cd projects/myapp-uat
   ```

2. **Update terraform.tfvars**
   Edit `terraform.tfvars` and replace placeholder values:
   - `project_name`: Your project name
   - `system_node_count`: Number of system nodes to deploy (default: 2)
   - `system_node_vm_size`: VM size for system nodes (default: Standard_F4s_v2)
   - `system_node_data_disks`: Data disk configuration (size, type, LUN)
   - `ssh_public_key`: Your actual SSH public key (from `~/.ssh/azure_vm_key.pub`)
   - `tags`: Update with your organization's tagging requirements

3. **Initialize Terraform**
   ```bash
   terraform init
   ```
   
   If using backend configuration with dynamic values:
   ```bash
   terraform init \
     -backend-config="storage_account_name=tfstate<unique-id>" \
     -backend-config="container_name=tfstate" \
     -backend-config="key=uat/terraform.tfstate"
   ```

4. **Review the Plan**
   ```bash
   terraform plan
   ```
   
   Review the proposed changes carefully before applying.

5. **Apply the Configuration**
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted to confirm.

6. **View Outputs**
   ```bash
   terraform output
   ```
   
   This displays important information like VM IPs and resource IDs.

## 🌍 Adding New Environments

To add a new environment (e.g., `dev` or `prod`):

1. **Use the scaffold script** (recommended)
   ```bash
   ./tf-scaffold.sh
   # Select project name and environment
   ```

   Or **copy manually**:
   ```bash
   cp -r projects/myapp-uat projects/myapp-dev
   ```

2. **Update environment-specific files**
   
   In `projects/myapp-dev/`:
   
   a. **terraform.t       = "myproject"
      environment         = "dev"
      location            = "Southeast Asia"
      system_node_count   = 1  # Fewer nodes for dev
      system_node_vm_size = "Standard_F2s_v2"  # Smaller for dev
      system_node_data_disks = [
        {
          name_suffix          = "data01"
          disk_size_gb         = 128  # Smaller disk for dev
          storage_account_type = "StandardSSD_LRS"
          lun                  = 0
          caching              = "ReadWrite"
        }
      ]
      vnet_address_space     utheast Asia"
      vm_size      = "Standard_B1s"  # Smaller for dev
      vnet_address_space = ["10.20.0.0/16"]
      subnet_address_prefixes = ["10.20.1.0/24"]
      # ... other values
      ```
   
   b. **variables.tf**: Update default value for `environment`
      ```hcl
      variable "environment" {
        description = "Environment name"
        type        = string
        default     = "dev"
      }
      ```
   
   c. **backend.tf**: Update the state file key
      ```hcl
      key = "dev/terraform.tfstate"
      ```

3. **Initialize and deploy**VM Count | Data Disk | Address Space | Use Case |
|-------------|----------------|----------|-----------|---------------|----------|
| **UAT** | Standard_F4s_v2 | 2 | 256 GiB SSD | 10.10.0.0/16 | User acceptance testing |
| **Dev** | Standard_F2s_v2 | 1 | 128 GiB SSD | 10.20.0.0/16 | Development and testing |
| **Prod** | Standard_F8s_v2 | 3+ | 512 GiB Premium
   terraform apply
   ```

### Environment-Specific Considerations

| Environment | VM Size | VM Count | Data Disk | Address Space | Workload Sub | Use Case |
|-------------|---------|----------|-----------|---------------|--------------|----------|
| **UAT** | Standard_F4s_v2 | 2 | 256 GiB SSD | 10.10.0.0/16 | Can be same | User acceptance testing |
| **Dev** | Standard_F2s_v2 | 1 | 128 GiB SSD | 10.20.0.0/16 | Can be same | Development and testing |
| **Prod** | Standard_F8s_v2 | 3+ | 512 GiB Premium | 10.0.0.0/16 | Should differ | Production workloads |

**Notes**:
- All environments can share the same management subscription for state
- UAT and Dev can share the same workload subscription (isolated by resource groups)
- Production should use a separate workload subscription for enhanced isolation
- Each environment has its own state file: `uat/terraform.tfstate`, `dev/terraform.tfstate`, `prod/terraform.tfstate`

## 🔧 Customization

### Scaling System Nodes

To change the number of system nodes, simply update `system_node_count` in `terraform.tfvars`:

```hcl
system_node_count = 3  # Deploy 3 system nodes instead of 2
```

Then run:
```bash
terraform plan
terraform apply
```

### Adding Worker Nodes or Different VM Groups

In `projects/<project-env>/main.tf`, add additional module blocks for different roles:

```hcl
module "worker_nodes" {
  source = "../../modules/azure-vm"

  vm_name_prefix      = "vm-${var.project_name}-${var.environment}-worker"
  vm_count            = 3
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.main.id
  vm_size             = "Standard_D4s_v3"
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  enable_public_ip    = false
  data_disks          = [
    {
      name_suffix          = "data01"
      disk_size_gb         = 512
      storage_account_type = "Premium_LRS"
      lun                  = 0
      caching              = "ReadWrite"
    }
  ]

  tags = merge(var.tags, { Role = "worker-node" })
}
```

### Modifying Data Disk Configuration

To add more data disks or change disk specifications, update `system_node_data_disks` in `terraform.tfvars`:

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
    name_suffix          = "data02"
    disk_size_gb         = 512
    storage_account_type = "Premium_LRS"
    lun                  = 1
    caching              = "ReadOnly"
  }
]
```

**Important**: Ensure each disk has a unique `lun` (Logical Unit Number) per VM.

### Enabling Public IP Access

To enable public IPs for system nodes, set in `terraform.tfvars`:
```hcl
enable_public_ip = true
```

Or configure per module in `main.tf`:
```hcl
module "system_nodes" {
  # ... other parameters ...
  enable_public_ip = true
}
```

### Adding Additional Subnets

In `projects/<project-env>/main.tf`:
```hcl
resource "azurerm_subnet" "additional" {
  name                 = "snet-${var.project_name}-${var.environment}-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.3.0/24"]
}
```

### Adding New PaaS Modules with Private Endpoints

To add a new PaaS service (e.g., Storage Account, AKS, PostgreSQL) that uses Private Endpoints:

1. **Create or use a module** that accepts `pe_subnet_id` and `vnet_id`
2. **Call the module** in `projects/<project-env>/main.tf` passing the PE subnet:

```hcl
module "storage_account" {
  source = "../../modules/azure-storage"

  storage_account_name = "st${var.project_name}${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  
  # Use the existing PE subnet
  pe_subnet_id         = azurerm_subnet.pe.id
  vnet_id              = azurerm_virtual_network.main.id
  
  tags = var.tags
}
```

**Benefits**:
- All PaaS services share the same PE subnet (no subnet sprawl)
- No need to create networking inside each module
- Consistent pattern across all PaaS modules
- If isolation is needed, add a dedicated subnet at the environment level

## 🔐 Security Best Practices

### State File Security

1. **Azure AD Authentication**: This project uses `use_azuread_auth = true` to authenticate to state storage
   - No storage account keys in configuration
   - Access controlled via RBAC
   - Supports managed identities and service principals

2. **Cross-Subscription Isolation**: State storage in separate management subscription
   - Limits blast radius of compromised workload subscription
   - Centralized governance of state files
   - Independent access control policies

3. **Never Commit Secrets**:
   - `backend.hcl` is gitignored (contains subscription IDs)
   - `terraform.tfvars` is gitignored (contains SSH keys, subscription IDs)
   - Use `backend.hcl.example` and `terraform.tfvars.example` as templates

### Network Security

1. **Private Endpoints**: ACR is configured with Private Endpoints by default (no public access)
   - Images are pulled over private network within the VNet
   - No data exfiltration risk through public internet
   - Update `acr_public_network_access_enabled = false` in `terraform.tfvars` to enforce

2. **SSH Access**: Update the NSG rule in your project's `main.tf` to restrict SSH access:
   ```hcl
   source_address_prefix = "YOUR_IP_ADDRESS/32"  # Instead of "*"
   ```

3. **Private Access**: Consider using Azure Bastion for SSH access instead of public IPs:
   ```hcl
   enable_public_ip = false
   ```

4. **Network Segmentation**: 
   - VM subnet and PE subnet are already separated
   - Consider adding application-tier subnets for further segmentation
   - Use Network Security Groups to control traffic between subnets

### RBAC Best Practices

1. **Principle of Least Privilege**:
   - Grant only necessary permissions
   - Use custom roles if Contributor is too broad
   - Scope roles to resource groups when possible

2. **Service Principal Rotation**:
   - Regularly rotate service principal secrets
   - Use Azure Key Vault to store secrets
   - Consider certificate-based authentication

3. **Audit Access**:
   - Enable Azure Activity Logs
   - Monitor state file access via Storage Analytics
   - Review role assignments periodically

## 🧹 Cleanup

To destroy all resources in an environment:

```bash
cd projects/myapp-uat
terraform destroy -var-file=terraform.tfvars
```

Or simply:
```bash
terraform destroy
```

**Warning**: This will permanently delete all resources in the environment!
ackend Configuration](https://www.terraform.io/docs/language/settings/backends/configuration.html)
- [Azure Storage Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## ❓ FAQ

### Why use partial backend configuration?

Backend blocks in Terraform cannot reference variables. Partial backend configuration with `-backend-config=backend.hcl` allows:
- Dynamic backend values per environment
- Keeping subscription IDs out of `.tf` files
- Flexible CI/CD pipeline configuration

### Can I use the same subscription for state and workloads?

Yes, but it's not recommended for production. Benefits of separation:
- Enhanced security through subscription-level isolation
- Centralized state governance across multiple workload subscriptions
- Independent cost tracking and management

### How do I migrate existing state to this setup?

```bash
# Backup existing state
terraform state pull > terraform.tfstate.backup

# Configure new backend
terraform init -backend-config=backend.hcl -migrate-state

# Verify
terraform state list
```

### Can multiple environments share the same workload subscription?

Yes, especially for non-production environments (dev/uat). Resources are isolated by resource groups. For production, use a separate subscription.

### How do I rotate the service principal secret?

```bash
# Create new secret
az ad sp credential reset --id <app-id>

# Update CI/CD pipeline or environment variables with new secret
# Test with new credentials
# Old secret expires automatically after rotation period
```
**Note**: The Terraform state file in the management subscription will remain. To clean up state storage:

```bash
# Delete the state file (optional, after destroying resources)
az storage blob delete \
  --account-name sttfstatemgmt001 \
  --container-name tfstate \
  --name uat/terraform.tfstate \
  --auth-mode login
```

## 🔧 Troubleshooting

### Backend Initialization Errors

**Error**: "Failed to get existing workspaces: storage: service returned error"

**Solution**: Verify:
1. Storage account exists in management subscription
2. You have "Storage Blob Data Contributor" role on the container
3. `backend.hcl` has correct subscription_id and tenant_id
4. You're authenticated (`az login` or service principal env vars)

### Authentication Errors

**Error**: "Error building AzureRM Client: obtain subscription() from Azure CLI"

**Solution**: 
```bash
# Re-authenticate
az login
az account set --subscription "<workload-subscription-id>"
```

### Provider Configuration Errors

**Error**: "Subscription() could not be determined"

**Solution**: Ensure `workload_subscription_id` is set correctly in `terraform.tfvars`

### State Locking Issues

**Error**: "Error acquiring the state lock"

**Solution**: 
1. Check if another Terraform process is running
2. If the lock is stale, break it (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```
2. **Private Access**: Consider using Azure Bastion for SSH access instead of public IPs:
   ```hcl
   enable_public_ip = false
   ```

3. **Network Segmentation**: Use separate VNets or subnets for different tiers (web, app, data)

### RBAC Best Practices

1. **Principle of Least Privilege**:
   - Grant only necessary permissions
   - Use custom roles if Contributor is too broad
   - Scope roles to resource groups when possible

2. **Service Principal Rotation**:
   - Regularly rotate service principal secrets
   - Use Azure Key Vault to store secrets
   - Consider certificate-based authentication

3. **Audit Access**:
   - Enable Azure Activity Logs
   - Monitor state file access via Storage Analytics
   - Review role assignments periodically

## 🧹 Cleanup

To destroy all resources in an environment:

```bash
cd projects/myapp-uat
terraform destroy
```

**Warning**: This will permanently delete all resources in the environment!

## 📚 Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Virtual Machines Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## 🤝 Contributing

When contributing to this repository:
1. Follow the established naming conventions
2. Document all variables and outputs
3. Test changes in a dev environment first
4. Use consistent formatting (`terraform fmt`)
5. Validate configurations (`terraform validate`)

## 📄 License

[Specify your license here]

## 👥 Maintainers

[List maintainers and contact information]
