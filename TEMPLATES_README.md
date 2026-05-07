# Terraform Environment Scaffolder - Template-Based Architecture

## Overview

The `tf-scaffold.sh` script uses **physical template files** on disk to generate new Terraform environments. No more heredocs or embedded code in the shell script—all configuration is stored as actual files that can be easily maintained, reviewed, and version-controlled.

## Architecture

### Template Directory Structure

```
templates/
├── base/                      # Base infrastructure (always included)
│   ├── main.tf                # Resource Group, VNet, Subnets
│   ├── variables.tf           # Base variable definitions
│   ├── terraform.tfvars       # Base configuration values
│   └── backend.tf             # Backend configuration
└── modules/                   # Module-specific templates (selectively included)
    ├── azure-acr/
    │   ├── main.tf            # ACR module block
    │   ├── terraform.tfvars   # ACR configuration
    │   └── variables.tf       # ACR variable definitions
    ├── azure-aks/
    │   ├── main.tf            # AKS module block
    │   ├── terraform.tfvars   # AKS configuration
    │   └── variables.tf       # (optional) AKS variables
    ├── azure-cosmosdb/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    ├── azure-keyvault/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    ├── azure-redis/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    └── azure-vm/
        ├── main.tf
        ├── terraform.tfvars
        └── variables.tf
```

## How It Works

### 1. Input Collection

```bash
./tf-scaffold.sh
```

Script prompts for:
- **Project name**: `cics`
- **Environment name**: `cics-dev`
- **Module selection**: `1 2 4` (ACR, AKS, Key Vault)

### 2. File Assembly

The script concatenates template files:

```bash
# main.tf (assembly of base + modules)
cat templates/base/main.tf                > projects/cics-dev/main.tf
cat templates/modules/azure-acr/main.tf  >> projects/cics-dev/main.tf
cat templates/modules/azure-aks/main.tf  >> projects/cics-dev/main.tf
cat templates/modules/azure-keyvault/main.tf >> projects/cics-dev/main.tf

# terraform.tfvars (assembly of base + modules)
cat templates/base/terraform.tfvars                > projects/cics-dev/terraform.tfvars
cat templates/modules/azure-acr/terraform.tfvars  >> projects/cics-dev/terraform.tfvars
cat templates/modules/azure-aks/terraform.tfvars  >> projects/cics-dev/terraform.tfvars
cat templates/modules/azure-keyvault/terraform.tfvars >> projects/cics-dev/terraform.tfvars

# variables.tf (assembly of base + modules)
cat templates/base/variables.tf                > projects/cics-dev/variables.tf
cat templates/modules/azure-acr/variables.tf  >> projects/cics-dev/variables.tf
# ...

# backend.tf (direct copy with substitutions)
cat templates/base/backend.tf > projects/cics-dev/backend.tf
```

### 3. Placeholder Substitution

After assembly, the script replaces placeholders throughout all generated files:

| Placeholder | Replacement | Example |
|-------------|-------------|---------|
| `__PROJECT_NAME__` | User input | `cics` |
| `__ENV_NAME__` | User input | `cics-dev` |
| `__ENV_NAME_UPPER__` | Uppercase env | `CICS-DEV` |
| `__DATE__` | Current date | `2026-05-05` |

## Template Placeholders

Use these placeholders in your template files:

```hcl
# Example: templates/base/main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  
  tags = var.tags
}

# Example: templates/base/terraform.tfvars
project_name = "__PROJECT_NAME__"
environment  = "__ENV_NAME__"
location     = "Southeast Asia"

tags = {
  Environment = "__ENV_NAME_UPPER__"
  Project     = "__PROJECT_NAME__"
  CreatedDate = "__DATE__"
}

# Example: templates/modules/azure-acr/terraform.tfvars
acr_name = "acr__PROJECT_NAME____ENV_NAME__"
```

## Maintaining Templates

### Adding a New Module

1. **Create directory**:
   ```bash
   mkdir templates/modules/azure-newmodule
   ```

2. **Create main.tf**:
   ```hcl
   # templates/modules/azure-newmodule/main.tf
   
   # -------------------------------------------------------------------
   # Azure New Module
   # -------------------------------------------------------------------
   module "new_module" {
     source = "../../modules/azure-newmodule"
     
     # ... module configuration
   }
   ```

3. **Create terraform.tfvars**:
   ```hcl
   # templates/modules/azure-newmodule/terraform.tfvars
   
   # ===================================================================
   # Azure New Module Configuration
   # ===================================================================
   new_module_name = "__PROJECT_NAME__-__ENV_NAME__-newmodule"
   new_module_sku  = "Standard"
   ```

4. **Create variables.tf** (optional):
   ```hcl
   # templates/modules/azure-newmodule/variables.tf
   
   variable "new_module_name" {
     description = "Name of the new module"
     type        = string
   }
   ```

5. **Update script**:
   Edit `tf-scaffold.sh` and add to the MODULES array:
   ```bash
   declare -a MODULES=(
     "azure-acr"
     "azure-aks"
     "azure-cosmosdb"
     "azure-keyvault"
     "azure-redis"
     "azure-vm"
     "azure-newmodule"  # <-- Add here
   )
   ```

### Updating Base Infrastructure

Simply edit the files in `templates/base/`:
- `main.tf` - Add/modify base resources
- `variables.tf` - Add/modify variable definitions
- `terraform.tfvars` - Update default values
- `backend.tf` - Modify backend configuration

All future environments will inherit these changes.

### Updating Module Templates

Edit the files in `templates/modules/<module-name>/`:
- Changes apply to all future environments that select this module
- Existing environments are not affected (you control when to update)

## Example Usage

### Scenario 1: Development Environment with ACR and AKS

```bash
./tf-scaffold.sh

Project name: myapp
Environment name: dev
Available modules:
  1. azure-acr
  2. azure-aks
  3. azure-cosmosdb
  4. azure-keyvault
  5. azure-redis
  6. azure-vm

Enter module numbers: 1 2

✓ Selected modules:
  • azure-acr
  • azure-aks

Generating configuration from templates...
  → Assembling main.tf...
  → Assembling variables.tf...
  → Assembling terraform.tfvars...
  → Generating backend.tf...

✓ Environment scaffolded successfully!

Created files in projects/dev/
  ✓ main.tf (112 lines)
  ✓ variables.tf (78 lines)
  ✓ terraform.tfvars (95 lines)
  ✓ backend.tf (38 lines)
```

**Generated main.tf** contains:
- Resource Group (from `templates/base/main.tf`)
- VNet and Subnets (from `templates/base/main.tf`)
- ACR module block (from `templates/modules/azure-acr/main.tf`)
- AKS module block (from `templates/modules/azure-aks/main.tf`)

### Scenario 2: Production with All Services

```bash
./tf-scaffold.sh

Project name: myapp
Environment name: prod
Enter module numbers: all
```

Includes all modules in the generated environment.

## Benefits of Template-Based Approach

### 1. **Maintainability**
- Templates are actual files, easy to edit with IDE
- Syntax highlighting and validation
- Can be linted and formatted
- Clear separation of concerns

### 2. **Version Control**
- Templates are versioned alongside code
- Easy to diff changes
- Can track template evolution
- Revert changes easily

### 3. **Testing**
- Can test templates independently
- Validate with `terraform fmt`, `terraform validate`
- Run linters like `tflint` on templates

### 4. **Collaboration**
- Team members can easily modify templates
- PRs show clear diffs
- No need to understand bash heredocs
- Self-documenting structure

### 5. **Flexibility**
- Easy to add new modules
- Simple to modify existing templates
- No shell scripting knowledge needed to update templates
- Placeholders are clear and consistent

### 6. **Reusability**
- Templates can be copied to other projects
- Can be packaged as a template library
- Easy to share best practices

## Troubleshooting

### Missing Template Files

If you see:
```
Warning: Template not found: templates/modules/azure-acr/main.tf
```

Verify the file exists:
```bash
ls -la templates/modules/azure-acr/
```

### Incorrect Substitutions

Check placeholders in template files:
```bash
grep -r "__PROJECT_NAME__" templates/
grep -r "__ENV_NAME__" templates/
```

### Module Not Available

Edit `tf-scaffold.sh` and ensure the module is in the MODULES array.

## Best Practices

### 1. Keep Templates DRY
- Use placeholders instead of hardcoding values
- Leverage Terraform variables and expressions

### 2. Document Templates
- Add comments explaining configuration choices
- Include examples in comments
- Reference Azure documentation

### 3. Use Consistent Naming
- Follow naming conventions in templates
- Use `__PLACEHOLDER__` format (double underscores)

### 4. Test Before Committing
- Run `terraform fmt` on templates
- Test with the scaffold script
- Verify generated environments

### 5. Version Templates
- Commit templates to git
- Tag releases with semantic versioning
- Document breaking changes

## Comparison: Old vs New Approach

| Aspect | Old (Heredocs) | New (Files) |
|--------|---------------|-------------|
| **Editing** | Edit bash script | Edit template files |
| **Validation** | No syntax checking | IDE validation |
| **Version Control** | Large diffs in bash | Clean diffs per file |
| **Testing** | Hard to test | Easy to test |
| **Collaboration** | Bash knowledge required | No bash needed |
| **Maintenance** | Complex to update | Simple to update |
| **Modularity** | All in one script | Separate files |

## See Also

- **tf-scaffold.sh** - The scaffolding script
- **templates/** - Template directory
- **SCAFFOLD_USAGE.md** - User guide
- **QUICKSTART.md** - Project overview
