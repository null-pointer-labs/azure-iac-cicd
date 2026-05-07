# Azure Storage Backend Setup Guide

## Overview

This guide explains how to create an Azure Storage Account for storing Terraform state files remotely. Remote state enables team collaboration, state locking, and centralized state management across environments.

## Why Remote State?

**Benefits**:
- **Team Collaboration**: Multiple team members can work with the same state
- **State Locking**: Prevents concurrent modifications and corruption
- **Security**: State is encrypted at rest and in transit
- **Backup**: Azure Storage provides durability and backup options
- **Consistency**: Single source of truth across all environments

**Architecture**:
```
Management Subscription
└── Resource Group (e.g., rg-tfstate-mgmt)
    └── Storage Account (e.g., sttfstatemgmt001)
        └── Container: tfstate
            ├── dev/terraform.tfstate
            ├── uat/terraform.tfstate
            └── prod/terraform.tfstate
```

## Authentication Methods

### Azure AD Authentication (Recommended)

**Pros**:
- No storage keys to manage or rotate
- Uses Azure RBAC for access control
- Audit trail via Azure AD logs
- Works with user accounts, service principals, and managed identities

**Cons**:
- Requires RBAC role assignment
- Slightly more complex initial setup

### Storage Key Authentication

**Pros**:
- Simple setup
- No RBAC configuration needed

**Cons**:
- Keys must be managed and rotated
- Less secure (keys provide full account access)
- No granular permissions

**Recommendation**: Use Azure AD authentication for production workloads.

## Subscription Architecture

### Single Subscription Setup

Use one subscription for both state storage and workloads:

```
Azure Subscription
├── Resource Group: rg-tfstate-mgmt (state storage)
│   └── Storage Account: sttfstatemgmt001
└── Resource Group: rg-myapp-dev (workloads)
    └── Resources: VMs, VNets, etc.
```

**Use case**: Small teams, single tenant, cost-conscious setups

### Cross-Subscription Setup

Separate state storage from workloads:

```
Management Subscription
└── Resource Group: rg-tfstate-mgmt
    └── Storage Account: sttfstatemgmt001
        └── State files for all environments

Workload Subscriptions
├── Dev Subscription
│   └── Dev resources
├── UAT Subscription
│   └── UAT resources
└── Prod Subscription
    └── Prod resources
```

**Use case**: Enterprise, multi-tenant, strict separation of concerns

## RBAC Permissions

### Required Roles

**On Storage Account Container**:
- `Storage Blob Data Contributor`: Read, write, delete blobs (state files)
- `Storage Blob Data Reader`: Read-only access (for viewing state)

**On Workload Subscription**:
- `Contributor`: Create/modify/delete resources
- Or custom role with specific permissions

### Least Privilege Principle

Grant permissions at the narrowest scope:
- **Best**: Container level (`/containers/tfstate`)
- **Good**: Storage Account level
- **Avoid**: Resource Group or Subscription level (for state access)

## State File Organization

### Naming Conventions

**State file keys** (paths in the container):
```
<project>-<environment>/terraform.tfstate

Examples:
- myapp-dev/terraform.tfstate
- myapp-uat/terraform.tfstate
- myapp-prod/terraform.tfstate
```

**Benefits**:
- Clear separation per environment
- Easy to locate state files
- Supports multiple projects in one container

### Alternative: Separate Containers

For larger organizations, use separate containers:
```
Container: tfstate-dev
Container: tfstate-uat
Container: tfstate-prod
```

**Benefits**:
- Stronger isolation
- Different RBAC per environment
- Easier compliance and auditing

## Cost Considerations

### Storage Account SKU

- **Standard_LRS** (Locally Redundant Storage): $0.018/GB/month
  - Use for: Dev/test environments, non-critical state
- **Standard_GRS** (Geo-Redundant Storage): $0.036/GB/month
  - Use for: Production, disaster recovery requirements
- **Standard_ZRS** (Zone-Redundant Storage): $0.025/GB/month
  - Use for: High availability within region

### State File Size

Typical state file sizes:
- Small project: 10-100 KB
- Medium project: 100 KB - 1 MB
- Large project: 1-10 MB

**Cost impact**: Minimal - storage costs are negligible compared to compute resources.

### Lock Leases

Azure Storage uses blob leases for state locking:
- Cost: Included (no additional charge)
- Duration: Held during `terraform apply/plan` operations
- Cleanup: Automatically released on completion

## Security Best Practices

1. **Enable encryption**: All data encrypted at rest by default
2. **Require TLS 1.2+**: Use `--min-tls-version TLS1_2`
3. **Disable public access**: Use `--allow-blob-public-access false`
4. **Enable soft delete**: Recover accidentally deleted state files
5. **Use Azure AD auth**: Avoid storage keys
6. **Enable logging**: Audit access to state files
7. **Use Private Endpoints**: For highly secure environments

## Backup and Recovery

### Enable Soft Delete

Recover deleted state files within retention period:
```bash
az storage blob service-properties delete-policy update \
  --account-name sttfstatemgmt001 \
  --enable true \
  --days-retained 30
```

### Point-in-Time Restore

Enable blob versioning for automatic versioning:
```bash
az storage account blob-service-properties update \
  --account-name sttfstatemgmt001 \
  --resource-group rg-tfstate-mgmt \
  --enable-versioning true
```

### Manual Backup

Download state files periodically:
```bash
az storage blob download \
  --account-name sttfstatemgmt001 \
  --container-name tfstate \
  --name myapp-prod/terraform.tfstate \
  --file ./backups/terraform.tfstate.$(date +%Y%m%d) \
  --auth-mode login
```

## Troubleshooting

### Error: Failed to get existing workspaces

**Cause**: Missing RBAC permissions

**Solution**:
```bash
az role assignment create \
  --assignee <user-or-sp-id> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<sa>/blobServices/default/containers/tfstate"
```

### Error: State lock acquisition failed

**Cause**: Another operation is in progress or stale lock

**Solution**:
1. Wait for the other operation to complete
2. If stale, force unlock:
   ```bash
   terraform force-unlock <lock-id>
   ```

### Error: Access denied

**Cause**: Insufficient permissions or wrong subscription context

**Solution**:
```bash
# Set correct subscription
az account set --subscription "<management-sub-id>"

# Verify authentication
az account show
```

## References

- [Terraform Azure Backend Documentation](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Security Guide](https://docs.microsoft.com/en-us/azure/storage/common/storage-security-guide)
- [Azure RBAC Built-in Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
