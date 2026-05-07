# Terraform Scaffold Script - Rewrite Summary

## Overview
Rewrote `tf-scaffold.sh` to use existing projects as templates instead of hardcoded boilerplate.

## Changes Made

### 1. **Template-Based Approach**
- Script now reads from existing project directories (e.g., `projects/myapp-uat/`) as the source template
- Falls back to minimal hardcoded templates if source files don't exist

### 2. **New Workflow**
```
1. Ask for project name (e.g., "cics")
2. Ask for environment name (e.g., "cics-dev")  
3. Show numbered module selector (same as before)
4. Process templates with intelligent substitution
```

### 3. **File Generation Strategy**

#### **projects/<project-env>/main.tf**
- Copies from source project (e.g., `projects/myapp-uat/main.tf`)
- Replaces all occurrences of "uat" → new environment name
- Filters out module blocks for unselected modules
- Keeps terraform{}, provider{}, resource_group, VNet, subnet blocks

#### **projects/<project-env>/terraform.tfvars**
- Copies from source project (e.g., `projects/myapp-uat/terraform.tfvars`)
- Replaces "uat" → new env name
- Replaces project_name value
- For each selected module:
  - Parses module's `modules/<module>/variables.tf`
  - Generates tfvars entries with descriptions
  - Pre-populates defaults when available
  - Pre-populates project_name/environment references

#### **projects/<project-env>/variables.tf**
- Direct copy from source project (e.g., `projects/myapp-uat/variables.tf`)
- No substitutions needed (shared structure)

#### **projects/<project-env>/backend.tf**
- Copies from source project (e.g., `projects/myapp-uat/backend.tf`) if exists
- Replaces "uat" → new env name

#### **Additional Files**
- `backend.hcl.example` - copied with substitutions if present
- `outputs.tf` - copied with substitutions if present
- `providers.tf` - copied with substitutions if present

### 4. **Substitution Rules**
- `"uat"` → `new_env_name` (case-insensitive)
- `"UAT"` → `NEW_ENV_NAME` (uppercase)
- `"Uat"` → `New_env_name` (title case)
- `rg-*-uat` → `rg-*-<env>`
- `*-uat-*` → `*-<env>-*`
- `project_name = "..."` → `project_name = "<entered_project>"`

### 5. **Module Filtering**
- Script parses UAT main.tf for module blocks
- Extracts module source path
- Only includes modules that were selected
- Preserves all non-module infrastructure (RG, VNet, subnets)

### 6. **Smart Variable Generation**
- For each module variable:
  - Skips internal variables (location, resource_group_name, tags, etc.)
  - Uses default value if present
  - Pre-fills project_name/environment with actual values
  - Generates TODO placeholders for required inputs
  - Infers values based on variable type (bool, number, list, string)

### 7. **New Features**
- **Diff Summary**: Shows what substitutions were applied
- **File List**: Displays all generated files with line counts
- **Better UX**: Color-coded output with progress indicators

## Example Usage

```bash
./tf-scaffold.sh
```

**Prompts:**
1. `Project name:` → cics
2. `Environment name:` → cics-dev
3. `Available modules:` → 1 2 4 (select ACR, AKS, Key Vault)

**Output:**
```
projects/cics-dev/
  ✓ main.tf (187 lines)
  ✓ variables.tf (95 lines)
  ✓ terraform.tfvars (142 lines)
  ✓ backend.tf (23 lines)
  ✓ backend.hcl.example (12 lines)
  ✓ outputs.tf (45 lines)
  ✓ providers.tf (18 lines)
```

## Benefits

1. **DRY Principle**: Single source of truth (UAT environment)
2. **Consistency**: All environments follow the same structure
3. **Maintainability**: Update UAT, all future environments get updates
4. **Intelligent**: Reads module variables dynamically
5. **Flexible**: Falls back to hardcoded templates if UAT missing
6. **Safe**: Module filtering prevents unwanted resources

## Testing

To test the script:

```bash
# Dry run (generate a test environment)
./tf-scaffold.sh
# Enter: testproject, test-env, modules: 1 2

# Verify output
ls -la projects/test-env/
cat projects/test-env/terraform.tfvars
```

## Notes

- The script is idempotent (can be re-run safely)
- Prompts for confirmation before overwriting existing directories
- All UAT template files are preserved unchanged
- Script maintains backward compatibility via fallback functions
