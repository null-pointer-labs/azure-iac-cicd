# ===================================================================
# UAT Environment - Main Configuration
# ===================================================================
# This configuration deploys the UAT environment infrastructure
# including Resource Group, VNet, Subnet, and Virtual Machines
# ===================================================================

# -------------------------------------------------------------------
# Resource Group
# -------------------------------------------------------------------
# Creates a dedicated resource group for the UAT environment
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = var.tags
}

# -------------------------------------------------------------------
# Virtual Network
# -------------------------------------------------------------------
# Creates a VNet for the UAT environment
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# -------------------------------------------------------------------
# Subnets
# -------------------------------------------------------------------
# VM Subnet - for virtual machine deployments
resource "azurerm_subnet" "vm" {
  name                 = "snet-${var.project_name}-${var.environment}-vm"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.vm_subnet_address_prefixes
}

# Private Endpoint Subnet - for PaaS services (ACR, Storage, etc.)
resource "azurerm_subnet" "pe" {
  name                 = "snet-${var.project_name}-${var.environment}-pe"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.pe_subnet_address_prefixes
}

# AKS Subnet - for Azure Kubernetes Service nodes
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.project_name}-${var.environment}-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefixes
}

# -------------------------------------------------------------------
# Network Security Group (Optional but recommended)
# -------------------------------------------------------------------
# Creates an NSG with basic SSH access rule
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow SSH from specific sources (update source_address_prefix as needed)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # IMPORTANT: Restrict this in production!
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with VM Subnet
resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# -------------------------------------------------------------------
# System Node Virtual Machines
# -------------------------------------------------------------------
# Deploy system nodes using the azure-vm module
# This will create multiple identical VMs with data disks
module "system_nodes" {
  source = "../../modules/azure-vm"

  vm_name_prefix      = "vm-${var.project_name}-${var.environment}-sys"
  vm_count            = var.system_node_count
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.vm.id
  vm_size             = var.system_node_vm_size
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  enable_public_ip    = var.enable_public_ip
  data_disks          = var.system_node_data_disks

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Role = "system-node"
    }
  )
}


# Example: Add more VM groups for different purposes
# module "worker_nodes" {
#   source = "../../modules/azure-vm"
#
#   vm_name_prefix      = "vm-${var.project_name}-${var.environment}-worker"
#   vm_count            = 3
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   subnet_id           = azurerm_subnet.main.id
#   vm_size             = "Standard_D4s_v3"
#   admin_username      = var.admin_username
#   ssh_public_key      = var.ssh_public_key
#   enable_public_ip    = false
#   data_disks          = var.system_node_data_disks
#
#   tags = merge(
#     var.tags,
#     {
#       Role = "worker-node"
#     }
#   )
# }

# -------------------------------------------------------------------
# Azure Container Registry
# -------------------------------------------------------------------
# Deploy container registry using the azure-acr module with Private Endpoint
module "container_registry" {
  source = "../../modules/azure-acr"

  acr_name            = var.acr_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.acr_sku

  # Private Endpoint configuration
  enable_private_endpoint = var.acr_enable_private_endpoint
  pe_subnet_id            = azurerm_subnet.pe.id
  vnet_id                 = azurerm_virtual_network.main.id

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "container-registry"
    }
  )
}

# -------------------------------------------------------------------
# Azure Redis Cache
# -------------------------------------------------------------------
# Deploy Redis Cache using the azure-redis module
module "redis_cache" {
  source = "../../modules/azure-redis"

  redis_name          = var.redis_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.redis_sku_name
  family              = var.redis_family
  capacity            = var.redis_capacity

  # Private Endpoint configuration (only for Standard/Premium SKUs)
  enable_private_endpoint = var.redis_enable_private_endpoint
  pe_subnet_id            = var.redis_enable_private_endpoint ? azurerm_subnet.pe.id : null
  vnet_id                 = var.redis_enable_private_endpoint ? azurerm_virtual_network.main.id : null

  # Security settings
  public_network_access_enabled = !var.redis_enable_private_endpoint

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "redis-cache"
    }
  )
}

# -------------------------------------------------------------------
# Azure Kubernetes Service (AKS)
# -------------------------------------------------------------------
# Deploy AKS cluster using the azure-aks module
# Includes system node pool (for system workloads) and worker node pool (for application workloads)
module "aks_cluster" {
  source = "../../modules/azure-aks"

  aks_name            = var.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_dns_prefix
  sku_tier            = var.aks_sku_tier
  kubernetes_version  = var.aks_kubernetes_version
  aks_subnet_id       = azurerm_subnet.aks.id

  # System Node Pool Configuration
  system_node_pool_name           = var.aks_system_node_pool_name
  system_node_pool_count          = var.aks_system_node_pool_count
  system_node_pool_vm_size        = var.aks_system_node_pool_vm_size
  system_node_pool_os_disk_size_gb = var.aks_system_node_pool_os_disk_size_gb
  system_node_pool_os_disk_type   = var.aks_system_node_pool_os_disk_type

  # Worker Node Pool Configuration
  worker_node_pool_name           = var.aks_worker_node_pool_name
  worker_node_pool_count          = var.aks_worker_node_pool_count
  worker_node_pool_vm_size        = var.aks_worker_node_pool_vm_size
  worker_node_pool_os_disk_size_gb = var.aks_worker_node_pool_os_disk_size_gb
  worker_node_pool_os_disk_type   = var.aks_worker_node_pool_os_disk_type

  # Network Configuration
  network_plugin = var.aks_network_plugin
  network_policy = var.aks_network_policy
  service_cidr   = var.aks_service_cidr
  dns_service_ip = var.aks_dns_service_ip

  # Security Configuration
  enable_azure_ad_rbac    = var.aks_enable_azure_ad_rbac
  tenant_id               = var.aks_enable_azure_ad_rbac ? var.tenant_id : null
  private_cluster_enabled = var.aks_private_cluster_enabled

  # Monitoring Configuration
  enable_monitoring           = var.aks_enable_monitoring
  log_analytics_workspace_id  = var.aks_enable_monitoring ? var.aks_log_analytics_workspace_id : null

  # Apply environment tags
  tags = merge(
    var.tags,
    {
      Service = "kubernetes"
    }
  )
}

