<#
.SYNOPSIS
    Terraform Environment Scaffolder - PowerShell Edition

.DESCRIPTION
    Interactively scaffolds a new Terraform environment by reading
    physical template files and performing substitutions.

.EXAMPLE
    .\tf-scaffold.ps1
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

# Stop on errors
$ErrorActionPreference = "Stop"

# ===================================================================
# Color definitions for console output
# ===================================================================
$Colors = @{
    Cyan   = 'Cyan'
    Green  = 'Green'
    Yellow = 'Yellow'
    Red    = 'Red'
    Blue   = 'Blue'
}

# ===================================================================
# Paths
# ===================================================================
$TEMPLATES_DIR = "templates"
$BASE_TEMPLATES = Join-Path $TEMPLATES_DIR "base"
$MODULE_TEMPLATES = Join-Path $TEMPLATES_DIR "modules"

# ===================================================================
# Available modules to select
# ===================================================================
$MODULES = @(
    "azure-acr",
    "azure-aks",
    "azure-cosmosdb",
    "azure-keyvault",
    "azure-redis",
    "azure-vm"
)

# ===================================================================
# Global variables (populated during script execution)
# ===================================================================
$script:SELECTED_MODULES = @()
$script:PROJECT_NAME = ""
$script:ENV_NAME = ""
$script:ENV_NAME_UPPER = ""
$script:CURRENT_DATE = ""
$script:USE_EXISTING_PRIVATE_DNS = $false
$script:DNS_SUBSCRIPTION_ID = ""
$script:DNS_ZONE_RG = ""

# Environment variables from .env file (if exists)
$script:WORKLOAD_SUBSCRIPTION_ID = ""
$script:TENANT_ID = ""
$script:LOCATION = ""
$script:BACKEND_SUBSCRIPTION_ID = ""
$script:BACKEND_RESOURCE_GROUP = ""
$script:BACKEND_STORAGE_ACCOUNT = ""
$script:BACKEND_CONTAINER = ""

# ===================================================================
# Helper Functions
# ===================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" -Color $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "ℹ $Message" -Color $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" -Color $Colors.Red
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "• $Message" -Color $Colors.Cyan
}

# ===================================================================
# Load .env file
# ===================================================================
function Load-EnvFile {
    $envFile = ".env"
    
    if (Test-Path $envFile) {
        Write-Success "Found .env file - loading default values..."
        Write-Host ""
        
        # Read and parse .env file
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            
            # Skip empty lines and comments
            if ($line -and -not $line.StartsWith('#')) {
                $parts = $line -split '=', 2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim().Trim('"').Trim("'")
                    
                    # Set script-level variables
                    switch ($key) {
                        "WORKLOAD_SUBSCRIPTION_ID" { $script:WORKLOAD_SUBSCRIPTION_ID = $value }
                        "TENANT_ID" { $script:TENANT_ID = $value }
                        "LOCATION" { $script:LOCATION = $value }
                        "BACKEND_SUBSCRIPTION_ID" { $script:BACKEND_SUBSCRIPTION_ID = $value }
                        "BACKEND_RESOURCE_GROUP" { $script:BACKEND_RESOURCE_GROUP = $value }
                        "BACKEND_STORAGE_ACCOUNT" { $script:BACKEND_STORAGE_ACCOUNT = $value }
                        "BACKEND_CONTAINER" { $script:BACKEND_CONTAINER = $value }
                        "DNS_SUBSCRIPTION_ID" { $script:DNS_SUBSCRIPTION_ID = $value }
                        "DNS_ZONE_RG" { $script:DNS_ZONE_RG = $value }
                    }
                }
            }
        }
        
        # Show loaded values
        if ($script:WORKLOAD_SUBSCRIPTION_ID) {
            Write-Info "Workload Subscription: $($script:WORKLOAD_SUBSCRIPTION_ID.Substring(0, [Math]::Min(8, $script:WORKLOAD_SUBSCRIPTION_ID.Length)))..."
        }
        if ($script:TENANT_ID) {
            Write-Info "Tenant ID: $($script:TENANT_ID.Substring(0, [Math]::Min(8, $script:TENANT_ID.Length)))..."
        }
        if ($script:LOCATION) {
            Write-Info "Location: $script:LOCATION"
        }
        if ($script:BACKEND_SUBSCRIPTION_ID) {
            Write-Info "Backend Subscription: $($script:BACKEND_SUBSCRIPTION_ID.Substring(0, [Math]::Min(8, $script:BACKEND_SUBSCRIPTION_ID.Length)))..."
        }
        if ($script:DNS_SUBSCRIPTION_ID) {
            Write-Info "DNS Subscription: $($script:DNS_SUBSCRIPTION_ID.Substring(0, [Math]::Min(8, $script:DNS_SUBSCRIPTION_ID.Length)))..."
        }
        
        Write-Host ""
    } else {
        Write-Warning "No .env file found - you'll need to enter values manually"
        Write-Warning "Create .env from .env.example to save time on future runs"
        Write-Host ""
    }
}

# ===================================================================
# UI Functions
# ===================================================================

function Show-ModuleSelector {
    Write-ColorOutput "═══════════════════════════════════════════════════" -Color $Colors.Cyan
    Write-ColorOutput "  Terraform Environment Scaffolder" -Color $Colors.Cyan
    Write-ColorOutput "═══════════════════════════════════════════════════" -Color $Colors.Cyan
    Write-Host ""
    Write-Host "Available modules:" -ForegroundColor White
    Write-Host ""
    
    # Print numbered list of modules
    for ($i = 0; $i -lt $MODULES.Count; $i++) {
        $num = $i + 1
        Write-ColorOutput "  $num. " -Color $Colors.Green -NoNewline
        Write-Host $MODULES[$i]
    }
    
    Write-Host ""
    Write-Host "Enter module numbers separated by spaces (e.g., " -NoNewline
    Write-ColorOutput "1 3 5" -Color $Colors.Green -NoNewline
    Write-Host "), or " -NoNewline
    Write-ColorOutput "all" -Color $Colors.Green -NoNewline
    Write-Host " to select everything:"
    
    $selection = Read-Host
    
    # Handle "all" selection
    if ($selection -eq "all") {
        $script:SELECTED_MODULES = $MODULES
        return
    }
    
    # Parse space-separated numbers
    $script:SELECTED_MODULES = @()
    $selectedIndices = @()
    
    $numbers = $selection -split '\s+' | Where-Object { $_ }
    
    foreach ($num in $numbers) {
        # Validate that input is a number
        if ($num -notmatch '^\d+$') {
            Write-Error "Error: '$num' is not a valid number"
            exit 1
        }
        
        $numInt = [int]$num
        
        # Convert to 0-based index
        $idx = $numInt - 1
        
        # Validate range
        if ($idx -lt 0 -or $idx -ge $MODULES.Count) {
            Write-Error "Error: Number '$num' is out of range (valid: 1-$($MODULES.Count))"
            exit 1
        }
        
        # Add to selected indices (avoid duplicates)
        if ($selectedIndices -notcontains $idx) {
            $selectedIndices += $idx
            $script:SELECTED_MODULES += $MODULES[$idx]
        }
    }
    
    # Validate at least one module is selected
    if ($script:SELECTED_MODULES.Count -eq 0) {
        Write-Error "Error: No modules selected. Please select at least one module."
        exit 1
    }
}

# ===================================================================
# Template Processing Functions
# ===================================================================

function Invoke-PlaceholderSubstitution {
    param([string]$Content)
    
    # Replace all placeholders
    $Content = $Content -replace '__PROJECT_NAME__', $script:PROJECT_NAME
    $Content = $Content -replace '__ENV_NAME__', $script:ENV_NAME
    $Content = $Content -replace '__ENV_NAME_UPPER__', $script:ENV_NAME_UPPER
    $Content = $Content -replace '__DATE__', $script:CURRENT_DATE
    
    # Replace environment-specific values from .env (if loaded)
    if ($script:WORKLOAD_SUBSCRIPTION_ID) {
        $Content = $Content -replace 'TODO-YOUR-WORKLOAD-SUBSCRIPTION-ID', $script:WORKLOAD_SUBSCRIPTION_ID
        $Content = $Content -replace 'TODO: YOUR-WORKLOAD-SUBSCRIPTION-ID', $script:WORKLOAD_SUBSCRIPTION_ID
    }
    
    if ($script:TENANT_ID) {
        $Content = $Content -replace 'TODO-YOUR-TENANT-ID', $script:TENANT_ID
        $Content = $Content -replace 'TODO: <TENANT_ID>', $script:TENANT_ID
    }
    
    if ($script:LOCATION) {
        $Content = $Content -replace 'Southeast Asia', $script:LOCATION
    }
    
    if ($script:BACKEND_SUBSCRIPTION_ID) {
        $Content = $Content -replace 'TODO: <MANAGEMENT_SUBSCRIPTION_ID>', $script:BACKEND_SUBSCRIPTION_ID
    }
    
    if ($script:BACKEND_RESOURCE_GROUP) {
        $Content = $Content -replace 'TODO: rg-tfstate-mgmt', $script:BACKEND_RESOURCE_GROUP
    }
    
    if ($script:BACKEND_STORAGE_ACCOUNT) {
        $Content = $Content -replace 'TODO: sttfstatemgmt001', $script:BACKEND_STORAGE_ACCOUNT
    }
    
    if ($script:BACKEND_CONTAINER) {
        $Content = $Content -replace 'container_name       = "tfstate"', "container_name       = `"$script:BACKEND_CONTAINER`""
    }
    
    return $Content
}

function Test-ModuleSelected {
    param([string]$ModuleName)
    
    return $script:SELECTED_MODULES -contains $ModuleName
}

function Add-PrivateDnsModules {
    $hasPEModules = $false
    
    # Check if any module with Private Endpoint support is selected
    foreach ($module in $script:SELECTED_MODULES) {
        if ($module -in @('azure-acr', 'azure-keyvault', 'azure-cosmosdb')) {
            $hasPEModules = $true
            break
        }
    }
    
    if (-not $hasPEModules) {
        return ""
    }
    
    $output = @"

# ===================================================================
# Private DNS Configuration for Private Endpoints
# ===================================================================
# Conditional DNS module calls based on use_existing_private_dns flag
# ===================================================================

"@
    
    # Generate DNS module calls for each service with Private Endpoint
    if (Test-ModuleSelected "azure-acr") {
        $output += "# Azure Container Registry - Private DNS`n"
        if ($script:USE_EXISTING_PRIVATE_DNS) {
            $output += @'
module "acr_dns_existing" {
  count  = var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.container_registry.pe_private_ip
  dns_zone_name       = "privatelink.azurecr.io"
  record_name         = var.acr_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

'@
        } else {
            $output += @'
module "acr_dns_standalone" {
  count  = !var.use_existing_private_dns && var.acr_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.container_registry.pe_private_ip
  dns_zone_name      = "privatelink.azurecr.io"
  record_name        = var.acr_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

'@
        }
    }
    
    if (Test-ModuleSelected "azure-keyvault") {
        $output += "# Azure Key Vault - Private DNS`n"
        if ($script:USE_EXISTING_PRIVATE_DNS) {
            $output += @'
module "keyvault_dns_existing" {
  count  = var.use_existing_private_dns && var.keyvault_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.key_vault.pe_private_ip
  dns_zone_name       = "privatelink.vaultcore.azure.net"
  record_name         = var.keyvault_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

'@
        } else {
            $output += @'
module "keyvault_dns_standalone" {
  count  = !var.use_existing_private_dns && var.keyvault_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.key_vault.pe_private_ip
  dns_zone_name      = "privatelink.vaultcore.azure.net"
  record_name        = var.keyvault_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

'@
        }
    }
    
    if (Test-ModuleSelected "azure-cosmosdb") {
        $output += "# Azure Cosmos DB - Private DNS`n"
        if ($script:USE_EXISTING_PRIVATE_DNS) {
            $output += @'
module "cosmosdb_dns_existing" {
  count  = var.use_existing_private_dns && var.cosmosdb_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-registration"

  providers = {
    azurerm.dns_sub = azurerm.dns_sub
  }

  private_ip_address  = module.cosmos_db.pe_private_ip
  dns_zone_name       = "privatelink.mongo.cosmos.azure.com"  # Adjust based on API type
  record_name         = var.cosmosdb_account_name
  dns_zone_rg         = var.dns_zone_rg
  dns_subscription_id = var.dns_subscription_id
  tags                = var.tags
}

'@
        } else {
            $output += @'
module "cosmosdb_dns_standalone" {
  count  = !var.use_existing_private_dns && var.cosmosdb_enable_private_endpoint ? 1 : 0
  source = "../../modules/private-dns-standalone"

  private_ip_address = module.cosmos_db.pe_private_ip
  dns_zone_name      = "privatelink.mongo.cosmos.azure.com"  # Adjust based on API type
  record_name        = var.cosmosdb_account_name
  dns_zone_rg        = var.dns_zone_rg
  vnet_id            = azurerm_virtual_network.main.id
  location           = var.location
  tags               = var.tags
}

'@
        }
    }
    
    return $output
}

function Add-PrivateDnsVariables {
    $hasPEModules = $false
    
    # Check if any module with Private Endpoint support is selected
    foreach ($module in $script:SELECTED_MODULES) {
        if ($module -in @('azure-acr', 'azure-keyvault', 'azure-cosmosdb')) {
            $hasPEModules = $true
            break
        }
    }
    
    if (-not $hasPEModules) {
        return ""
    }
    
    $output = @"

# ===================================================================
# Private DNS Variables
# ===================================================================

variable "use_existing_private_dns" {
  description = "Use existing Private DNS Zones in separate subscription (true) or create standalone zones (false)"
  type        = bool
  default     = false
}

variable "dns_zone_rg" {
  description = "Resource Group for DNS Zones (in DNS subscription if cross-sub, or workload subscription if standalone)"
  type        = string
}

"@

    if ($script:USE_EXISTING_PRIVATE_DNS) {
        $output += @'
variable "dns_subscription_id" {
  description = "Subscription ID where Private DNS Zones exist (required when use_existing_private_dns = true)"
  type        = string
  default     = ""
}

'@
    }
    
    return $output
}

function Add-PrivateDnsTfvars {
    $hasPEModules = $false
    
    # Check if any module with Private Endpoint support is selected
    foreach ($module in $script:SELECTED_MODULES) {
        if ($module -in @('azure-acr', 'azure-keyvault', 'azure-cosmosdb')) {
            $hasPEModules = $true
            break
        }
    }
    
    if (-not $hasPEModules) {
        return ""
    }
    
    $output = @"

# ===================================================================
# Private DNS Configuration
# ===================================================================
"@

    if ($script:USE_EXISTING_PRIVATE_DNS) {
        $output += @"

# Cross-subscription DNS mode: Uses existing Private DNS Zones in DNS subscription
use_existing_private_dns = true
dns_subscription_id      = "$script:DNS_SUBSCRIPTION_ID"
dns_zone_rg              = "$script:DNS_ZONE_RG"

# Prerequisites for cross-subscription DNS:
# • Private DNS Zones exist in DNS subscription
# • VNet Links configured to hub VNet
# • VNet peering established between workload and hub VNets
# • RBAC: 'Private DNS Zone Contributor' role in DNS subscription
"@
    } else {
        $output += @"

# Standalone DNS mode: Creates new Private DNS Zones in workload subscription
use_existing_private_dns = false
dns_zone_rg              = "$script:DNS_ZONE_RG"
"@
    }
    
    $output += "`n"
    return $output
}

# ===================================================================
# File Generation Functions
# ===================================================================

function New-MainTf {
    param([string]$OutputFile)
    
    # Start with base infrastructure
    $content = Get-Content (Join-Path $BASE_TEMPLATES "main.tf") -Raw
    
    # Append module-specific infrastructure blocks conditionally
    $infraDir = Join-Path $TEMPLATES_DIR "infrastructure"
    if (Test-Path $infraDir) {
        # Include AKS subnet only if azure-aks module is selected
        if (Test-ModuleSelected "azure-aks") {
            $aksInfra = Join-Path $infraDir "azure-aks-subnet.tf"
            if (Test-Path $aksInfra) {
                $content += "`n" + (Get-Content $aksInfra -Raw)
            }
        }
    }
    
    # Append selected module blocks
    foreach ($module in $script:SELECTED_MODULES) {
        $moduleTemplate = Join-Path $MODULE_TEMPLATES $module "main.tf"
        if (Test-Path $moduleTemplate) {
            $content += Get-Content $moduleTemplate -Raw
        } else {
            Write-Warning "Template not found: $moduleTemplate"
        }
    }
    
    # Add Private DNS module calls for services with Private Endpoints
    $content += Add-PrivateDnsModules
    
    # Perform substitutions
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-TerraformTfvars {
    param([string]$OutputFile)
    
    # Start with base configuration
    $content = Get-Content (Join-Path $BASE_TEMPLATES "terraform.tfvars") -Raw
    
    # Append module-specific infrastructure tfvars conditionally
    $infraDir = Join-Path $TEMPLATES_DIR "infrastructure"
    if (Test-Path $infraDir) {
        # Include AKS subnet tfvars only if azure-aks module is selected
        if (Test-ModuleSelected "azure-aks") {
            $aksTfvars = Join-Path $infraDir "azure-aks-subnet.tfvars"
            if (Test-Path $aksTfvars) {
                $content += Get-Content $aksTfvars -Raw
            }
        }
    }
    
    # Append selected module configurations
    foreach ($module in $script:SELECTED_MODULES) {
        $moduleTfvars = Join-Path $MODULE_TEMPLATES $module "terraform.tfvars"
        if (Test-Path $moduleTfvars) {
            $content += Get-Content $moduleTfvars -Raw
        } else {
            Write-Warning "Template not found: $moduleTfvars"
        }
    }
    
    # Add Private DNS configuration
    $content += Add-PrivateDnsTfvars
    
    # Perform substitutions
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-VariablesTf {
    param([string]$OutputFile)
    
    # Start with base variables
    $content = Get-Content (Join-Path $BASE_TEMPLATES "variables.tf") -Raw
    
    # Append module-specific infrastructure variables conditionally
    $infraDir = Join-Path $TEMPLATES_DIR "infrastructure"
    if (Test-Path $infraDir) {
        # Include AKS subnet variables only if azure-aks module is selected
        if (Test-ModuleSelected "azure-aks") {
            $aksVars = Join-Path $infraDir "azure-aks-subnet.variables.tf"
            if (Test-Path $aksVars) {
                $content += Get-Content $aksVars -Raw
            }
        }
    }
    
    # Append selected module variable definitions
    foreach ($module in $script:SELECTED_MODULES) {
        $moduleVars = Join-Path $MODULE_TEMPLATES $module "variables.tf"
        if (Test-Path $moduleVars) {
            $content += Get-Content $moduleVars -Raw
        }
    }
    
    # Add Private DNS variables
    $content += Add-PrivateDnsVariables
    
    # Perform substitutions
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-BackendTf {
    param([string]$OutputFile)
    
    $backendTemplate = Join-Path $BASE_TEMPLATES "backend.tf"
    if (-not (Test-Path $backendTemplate)) {
        return
    }
    
    $content = Get-Content $backendTemplate -Raw
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-BackendHcl {
    param([string]$OutputFile)
    
    $backendTemplate = Join-Path $BASE_TEMPLATES "backend.hcl"
    if (-not (Test-Path $backendTemplate)) {
        return
    }
    
    $content = Get-Content $backendTemplate -Raw
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-BackendHclExample {
    param([string]$OutputFile)
    
    $backendTemplate = Join-Path $BASE_TEMPLATES "backend.hcl"
    if (-not (Test-Path $backendTemplate)) {
        return
    }
    
    # Use the same template, it already has TODO placeholders
    $content = Get-Content $backendTemplate -Raw
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

function New-ProvidersTf {
    param([string]$OutputFile)
    
    $providersTemplate = Join-Path $BASE_TEMPLATES "providers.tf"
    if (-not (Test-Path $providersTemplate)) {
        return
    }
    
    $content = Get-Content $providersTemplate -Raw
    
    # Add cross-subscription DNS provider if needed
    if ($script:USE_EXISTING_PRIVATE_DNS) {
        $content += @'


# ===================================================================
# Provider: DNS Subscription (Cross-Subscription DNS Management)
# ===================================================================
# Used when use_existing_private_dns = true
# Accesses existing Private DNS Zones in a separate subscription

provider "azurerm" {
  alias = "dns_sub"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.dns_subscription_id
  tenant_id       = var.tenant_id
}
'@
    }
    
    $content = Invoke-PlaceholderSubstitution $content
    Set-Content -Path $OutputFile -Value $content -NoNewline
}

# ===================================================================
# Summary Functions
# ===================================================================

function Show-GenerationSummary {
    Write-Host ""
    Write-ColorOutput "═══════════════════════════════════════════════════" -Color $Colors.Blue
    Write-ColorOutput "  Generation Summary" -Color $Colors.Blue
    Write-ColorOutput "═══════════════════════════════════════════════════" -Color $Colors.Blue
    Write-Host ""
    Write-Host "Source:       $TEMPLATES_DIR/"
    Write-Host "Target:       projects/$script:PROJECT_NAME-$script:ENV_NAME/"
    Write-Host ""
    Write-Host "Substitutions applied:"
    Write-Host "  • " -NoNewline
    Write-ColorOutput "__PROJECT_NAME__" -Color $Colors.Yellow -NoNewline
    Write-Host " → " -NoNewline
    Write-ColorOutput $script:PROJECT_NAME -Color $Colors.Green
    Write-Host "  • " -NoNewline
    Write-ColorOutput "__ENV_NAME__" -Color $Colors.Yellow -NoNewline
    Write-Host " → " -NoNewline
    Write-ColorOutput $script:ENV_NAME -Color $Colors.Green
    Write-Host "  • " -NoNewline
    Write-ColorOutput "__ENV_NAME_UPPER__" -Color $Colors.Yellow -NoNewline
    Write-Host " → " -NoNewline
    Write-ColorOutput $script:ENV_NAME_UPPER -Color $Colors.Green
    Write-Host "  • " -NoNewline
    Write-ColorOutput "__DATE__" -Color $Colors.Yellow -NoNewline
    Write-Host " → " -NoNewline
    Write-ColorOutput $script:CURRENT_DATE -Color $Colors.Green
    Write-Host ""
    Write-Host "Modules included:"
    foreach ($module in $script:SELECTED_MODULES) {
        Write-Success $module
    }
    
    # List modules that were filtered out
    Write-Host ""
    Write-Host "Modules excluded:"
    foreach ($module in $MODULES) {
        if ($script:SELECTED_MODULES -notcontains $module) {
            Write-Error $module
        }
    }
    
    # Show Private DNS configuration if applicable
    $hasPEModules = $false
    foreach ($module in $script:SELECTED_MODULES) {
        if ($module -in @('azure-acr', 'azure-keyvault', 'azure-cosmosdb')) {
            $hasPEModules = $true
            break
        }
    }
    
    if ($hasPEModules) {
        Write-Host ""
        Write-Host "Private DNS Configuration:"
        if ($script:USE_EXISTING_PRIVATE_DNS) {
            Write-Success "Mode: Cross-Subscription (existing DNS zones)"
            Write-Success "DNS Subscription ID: $script:DNS_SUBSCRIPTION_ID"
            Write-Success "DNS Resource Group: $script:DNS_ZONE_RG"
        } else {
            Write-Success "Mode: Standalone (creates new DNS zones)"
            Write-Success "DNS Resource Group: $script:DNS_ZONE_RG"
        }
    }
    
    Write-Host ""
}

# ===================================================================
# Main Script Logic
# ===================================================================

function Invoke-Main {
    Write-ColorOutput "Terraform Environment Scaffolder" -Color $Colors.Cyan
    Write-Host ""
    
    # Load .env file if it exists
    Load-EnvFile
    
    # Step 1: Get project name
    Write-Host "Project name (e.g., cics, komopro):"
    $script:PROJECT_NAME = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($script:PROJECT_NAME)) {
        Write-Error "Error: Project name cannot be empty"
        exit 1
    }
    
    if ($script:PROJECT_NAME -notmatch '^[a-zA-Z0-9-]+$') {
        Write-Error "Error: Project name must be alphanumeric with hyphens only"
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Get environment name
    Write-Host "Environment name (e.g., dev, uat, prod):"
    $script:ENV_NAME = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($script:ENV_NAME)) {
        Write-Error "Error: Environment name cannot be empty"
        exit 1
    }
    
    if ($script:ENV_NAME -notmatch '^[a-zA-Z0-9-]+$') {
        Write-Error "Error: Environment name must be alphanumeric with hyphens only"
        exit 1
    }
    
    # Set derived variables
    $script:ENV_NAME_UPPER = $script:ENV_NAME.ToUpper()
    $script:CURRENT_DATE = Get-Date -Format "yyyy-MM-dd"
    
    Write-Host ""
    
    # Step 3: Module selection
    Show-ModuleSelector
    Clear-Host
    
    Write-Success "Selected modules:"
    foreach ($mod in $script:SELECTED_MODULES) {
        Write-Host "  • $mod"
    }
    Write-Host ""
    
    # Step 4: Private DNS configuration (if any PE-enabled modules selected)
    $needsDns = $false
    foreach ($module in $script:SELECTED_MODULES) {
        if ($module -in @('azure-acr', 'azure-keyvault', 'azure-cosmosdb')) {
            $needsDns = $true
            break
        }
    }
    
    if ($needsDns) {
        # Automatically detect DNS mode based on .env values
        if ($script:DNS_SUBSCRIPTION_ID -and $script:DNS_ZONE_RG) {
            # Cross-subscription mode: .env has both DNS values
            $script:USE_EXISTING_PRIVATE_DNS = $true
            Write-Success "Detected Cross-Subscription DNS mode from .env"
            Write-Host "  • DNS Subscription: $($script:DNS_SUBSCRIPTION_ID.Substring(0, [Math]::Min(8, $script:DNS_SUBSCRIPTION_ID.Length)))..."
            Write-Host "  • DNS Resource Group: $script:DNS_ZONE_RG"
        } else {
            # Standalone mode: No DNS values in .env
            $script:USE_EXISTING_PRIVATE_DNS = $false
            $script:DNS_ZONE_RG = "rg-$script:PROJECT_NAME-$script:ENV_NAME-dns"
            Write-Success "Using Standalone DNS mode (no DNS config in .env)"
            Write-Host "  • DNS Resource Group: $script:DNS_ZONE_RG"
        }
        Write-Host ""
    }
    
    $outputDir = "projects/$script:PROJECT_NAME-$script:ENV_NAME"
    
    # Step 5: Check if directory exists
    if (Test-Path $outputDir) {
        Write-Host ""
        Write-Warning "Warning: Directory '$outputDir' already exists"
        $confirm = Read-Host "Overwrite? (y/N)"
        
        if ($confirm -notin @('y', 'Y')) {
            Write-Error "Aborted."
            exit 0
        }
    }
    
    # Step 6: Create directory and generate files
    Write-Host ""
    Write-ColorOutput "Generating configuration from templates..." -Color $Colors.Cyan
    
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    
    # Generate main.tf
    Write-ColorOutput "  → Assembling main.tf..." -Color $Colors.Cyan
    New-MainTf (Join-Path $outputDir "main.tf")
    
    # Generate variables.tf
    Write-ColorOutput "  → Assembling variables.tf..." -Color $Colors.Cyan
    New-VariablesTf (Join-Path $outputDir "variables.tf")
    
    # Generate terraform.tfvars
    Write-ColorOutput "  → Assembling terraform.tfvars..." -Color $Colors.Cyan
    New-TerraformTfvars (Join-Path $outputDir "terraform.tfvars")
    
    # Generate backend.tf
    if (Test-Path (Join-Path $BASE_TEMPLATES "backend.tf")) {
        Write-ColorOutput "  → Generating backend.tf..." -Color $Colors.Cyan
        New-BackendTf (Join-Path $outputDir "backend.tf")
    }
    
    # Generate backend.hcl
    if (Test-Path (Join-Path $BASE_TEMPLATES "backend.hcl")) {
        Write-ColorOutput "  → Generating backend.hcl..." -Color $Colors.Cyan
        New-BackendHcl (Join-Path $outputDir "backend.hcl")
    }
    
    # Generate backend.hcl.example
    if (Test-Path (Join-Path $BASE_TEMPLATES "backend.hcl")) {
        Write-ColorOutput "  → Generating backend.hcl.example..." -Color $Colors.Cyan
        New-BackendHclExample (Join-Path $outputDir "backend.hcl.example")
    }
    
    # Generate providers.tf
    if (Test-Path (Join-Path $BASE_TEMPLATES "providers.tf")) {
        Write-ColorOutput "  → Generating providers.tf..." -Color $Colors.Cyan
        New-ProvidersTf (Join-Path $outputDir "providers.tf")
    }
    
    # Print summary
    Show-GenerationSummary
    
    # Step 7: Success summary
    Write-ColorOutput "✓ Environment scaffolded successfully!" -Color $Colors.Green
    Write-Host ""
    Write-Host "Created files in $outputDir/"
    Get-ChildItem $outputDir -File | ForEach-Object {
        $lineCount = (Get-Content $_.FullName | Measure-Object -Line).Lines
        Write-Success "$($_.Name) ($lineCount lines)"
    }
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Review generated files in $outputDir/"
    Write-Host "  2. Update TODO placeholders in terraform.tfvars"
    Write-Host "  3. Update backend.hcl with your Azure backend configuration"
    Write-Host "  4. Run: cd $outputDir && terraform init -backend-config=backend.hcl"
    Write-Host "  5. Run: terraform plan"
    Write-Host "  6. Run: terraform apply"
    Write-Host ""
}

# ===================================================================
# Script Entry Point
# ===================================================================

try {
    Invoke-Main
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
