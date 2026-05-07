# ===================================================================
# VNet Peering Configuration - Manual Setup Required
# ===================================================================
# INTENTIONALLY EXCLUDED FROM TERRAFORM AUTOMATION
# 
# Purpose: Document VNet peering requirements for cross-subscription DNS
# Context: When use_existing_private_dns = true
# ===================================================================

# ===================================================================
# Why VNet Peering is NOT Automated
# ===================================================================
# 
# VNet peering is intentionally excluded from this Terraform configuration for these reasons:
# 
# 1. LIFECYCLE MANAGEMENT
#    - Peering typically persists across multiple service deployments
#    - Should not be destroyed when individual services are torn down
#    - Managed independently from application infrastructure
# 
# 2. ORGANIZATIONAL BOUNDARIES
#    - Often managed by separate network/platform team
#    - Hub VNet may be in a different subscription with different ownership
#    - Requires coordination between teams
# 
# 3. CENTRALIZED GOVERNANCE
#    - Part of broader hub-spoke network architecture
#    - May have organizational policies, approval processes
#    - Could be managed by Azure Virtual WAN or other network automation
# 
# 4. SECURITY & COMPLIANCE
#    - Network connectivity changes often require security review
#    - May need change control board approval
#    - Audit trail typically managed separately
# 
# 5. BLAST RADIUS
#    - Peering affects network-wide connectivity
#    - Mistakes can impact multiple applications
#    - Safer to handle via specialized network automation
# 
# ===================================================================

# ===================================================================
# Prerequisites for Cross-Subscription Private DNS
# ===================================================================
# 
# Before deploying with use_existing_private_dns = true, ensure:
# 
# ✓ NETWORK CONNECTIVITY
#   - Bidirectional VNet peering between workload VNet and DNS hub VNet
#   - Peering configured with appropriate traffic forwarding settings
#   - No overlapping address spaces between peered VNets
# 
# ✓ DNS INFRASTRUCTURE
#   - Private DNS Zones exist in DNS subscription
#   - VNet Links configured between DNS Zones and hub VNet
#   - Appropriate DNS zones for services (e.g., privatelink.azurecr.io)
# 
# ✓ RBAC PERMISSIONS
#   - Terraform principal has "Private DNS Zone Contributor" in DNS subscription
#   - Terraform principal has "Network Contributor" in workload subscription
#   - Service principal can read DNS Zone details
# 
# ✓ NETWORK SECURITY
#   - NSG rules allow DNS traffic (UDP port 53) between VNets
#   - No Azure Firewall rules blocking DNS resolution
#   - Route tables configured correctly for hub-spoke topology
# 
# ===================================================================

# ===================================================================
# Manual VNet Peering Setup Instructions
# ===================================================================
# 
# OPTION 1: Azure Portal
# -----------------------
# 
# 1. Navigate to Workload VNet → Settings → Peerings
# 2. Click "+ Add"
# 3. Configure Workload → Hub Peering:
#    - Name: peer-workload-to-hub
#    - Remote VNet: Select DNS Hub VNet (cross-subscription)
#    - Allow forwarded traffic: Yes
#    - Allow gateway transit: No (or Yes if hub has VPN/ER)
# 4. Configure Hub → Workload Peering automatically created
# 5. Verify peering status shows "Connected"
# 
# 
# OPTION 2: Azure CLI
# --------------------
# 
# # Set variables
# WORKLOAD_VNET_ID="/subscriptions/WORKLOAD-SUB-ID/resourceGroups/rg-myproject-dev/providers/Microsoft.Network/virtualNetworks/vnet-myproject-dev"
# HUB_VNET_ID="/subscriptions/DNS-SUB-ID/resourceGroups/rg-dns-hub-prod/providers/Microsoft.Network/virtualNetworks/vnet-dns-hub"
# 
# # Create peering from workload to hub
# az network vnet peering create \
#   --name peer-workload-to-hub \
#   --resource-group rg-myproject-dev \
#   --vnet-name vnet-myproject-dev \
#   --remote-vnet $HUB_VNET_ID \
#   --allow-vnet-access true \
#   --allow-forwarded-traffic true \
#   --subscription WORKLOAD-SUB-ID
# 
# # Create peering from hub to workload
# az network vnet peering create \
#   --name peer-hub-to-workload \
#   --resource-group rg-dns-hub-prod \
#   --vnet-name vnet-dns-hub \
#   --remote-vnet $WORKLOAD_VNET_ID \
#   --allow-vnet-access true \
#   --allow-forwarded-traffic true \
#   --subscription DNS-SUB-ID
# 
# 
# OPTION 3: Separate Terraform (Recommended)
# -------------------------------------------
# 
# If you manage network infrastructure with Terraform, maintain a separate
# Terraform workspace/state for network resources:
# 
# File: network-infra/vnet-peerings.tf
# 
# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 4.0"
#     }
#   }
# }
# 
# provider "azurerm" {
#   alias           = "workload"
#   subscription_id = var.workload_subscription_id
#   features {}
# }
# 
# provider "azurerm" {
#   alias           = "dns_hub"
#   subscription_id = var.dns_subscription_id
#   features {}
# }
# 
# # Peering from workload VNet to DNS hub VNet
# resource "azurerm_virtual_network_peering" "workload_to_hub" {
#   provider                  = azurerm.workload
#   name                      = "peer-${var.project_name}-${var.environment}-to-hub"
#   resource_group_name       = var.workload_vnet_rg
#   virtual_network_name      = var.workload_vnet_name
#   remote_virtual_network_id = var.hub_vnet_id
# 
#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
#   use_remote_gateways          = false # Set to true if hub has VPN/ExpressRoute
# }
# 
# # Peering from DNS hub VNet to workload VNet
# resource "azurerm_virtual_network_peering" "hub_to_workload" {
#   provider                  = azurerm.dns_hub
#   name                      = "peer-hub-to-${var.project_name}-${var.environment}"
#   resource_group_name       = var.hub_vnet_rg
#   virtual_network_name      = var.hub_vnet_name
#   remote_virtual_network_id = var.workload_vnet_id
# 
#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = true  # If hub has VPN/ExpressRoute
#   use_remote_gateways          = false
# }
# 
# ===================================================================

# ===================================================================
# Verification Steps
# ===================================================================
# 
# After configuring VNet peering, verify:
# 
# 1. PEERING STATUS
#    az network vnet peering show \
#      --name peer-workload-to-hub \
#      --resource-group rg-myproject-dev \
#      --vnet-name vnet-myproject-dev \
#      --query "peeringState" -o tsv
#    # Expected: "Connected"
# 
# 2. DNS RESOLUTION FROM WORKLOAD VNET
#    - Deploy a test VM in workload VNet
#    - Run: nslookup myacr.privatelink.azurecr.io
#    - Should resolve to Private Endpoint IP (e.g., 10.10.2.5)
# 
# 3. CONNECTIVITY TEST
#    - From test VM: curl https://myacr.azurecr.io/v2/
#    - Should connect via Private Endpoint (not public internet)
# 
# 4. EFFECTIVE ROUTES
#    az network nic show-effective-route-table \
#      --name test-vm-nic \
#      --resource-group rg-myproject-dev \
#      --output table
#    # Verify route to DNS hub VNet address space
# 
# ===================================================================

# ===================================================================
# Troubleshooting Common Issues
# ===================================================================
# 
# ISSUE: DNS resolution fails
# SOLUTION:
#   - Verify VNet peering status is "Connected"
#   - Check Private DNS Zone VNet Link exists for hub VNet
#   - Ensure no NSG blocking UDP 53 (DNS)
#   - Verify DNS A record exists in Private DNS Zone
# 
# ISSUE: Peering stuck in "Updating" state
# SOLUTION:
#   - Wait 5-10 minutes for Azure to complete
#   - Check no overlapping address spaces
#   - Verify RBAC permissions on both VNets
# 
# ISSUE: Can't establish peering across subscriptions
# SOLUTION:
#   - Ensure authentication has access to both subscriptions
#   - Verify "Network Contributor" role in both subscriptions
#   - Check Azure Policy not blocking cross-subscription peering
# 
# ISSUE: Private Endpoint works locally but not from hub
# SOLUTION:
#   - Verify allow_forwarded_traffic = true on both sides
#   - Check route tables not dropping traffic
#   - Ensure no Azure Firewall rules blocking connectivity
# 
# ===================================================================

# ===================================================================
# Cost Considerations
# ===================================================================
# 
# VNet Peering costs (as of 2026):
# - Ingress traffic: ~$0.01 per GB
# - Egress traffic: ~$0.01 per GB
# - No charge for peering setup itself
# - Minimal cost for typical DNS traffic
# 
# Consider:
# - Global VNet peering costs more than regional
# - Use local peering when both VNets in same region
# - DNS traffic is minimal (<1 MB/day per service typically)
# 
# ===================================================================

# ===================================================================
# Reference Architecture
# ===================================================================
# 
# Typical hub-spoke topology with cross-subscription Private DNS:
# 
# ┌─────────────────────────────────────────────────────────────┐
# │ DNS Subscription (Hub)                                      │
# │                                                             │
# │  ┌─────────────────────────────────────────┐              │
# │  │ DNS Hub VNet (10.0.0.0/16)             │              │
# │  │                                         │              │
# │  │  ┌─────────────────────────────────┐   │              │
# │  │  │ Private DNS Zones:               │   │              │
# │  │  │ • privatelink.azurecr.io        │   │              │
# │  │  │ • privatelink.vaultcore.azure.net│   │              │
# │  │  │ • privatelink.*.cosmos.azure.com │   │              │
# │  │  │                                  │   │              │
# │  │  │ VNet Links → Hub VNet            │   │              │
# │  │  └─────────────────────────────────┘   │              │
# │  └─────────────────────────────────────────┘              │
# │                        ▲                                   │
# └────────────────────────┼───────────────────────────────────┘
#                          │
#                    VNet Peering
#                          │
# ┌────────────────────────┼───────────────────────────────────┐
# │ Workload Subscription  │                                   │
# │                        ▼                                   │
# │  ┌─────────────────────────────────────────┐              │
# │  │ Workload VNet (10.10.0.0/16)           │              │
# │  │                                         │              │
# │  │  ┌────────────────────────────────┐    │              │
# │  │  │ Private Endpoint Subnet        │    │              │
# │  │  │ (10.10.2.0/24)                 │    │              │
# │  │  │                                 │    │              │
# │  │  │  • PE-ACR (10.10.2.5)          │    │              │
# │  │  │  • PE-KeyVault (10.10.2.6)     │    │              │
# │  │  │  • PE-CosmosDB (10.10.2.7)     │    │              │
# │  │  └────────────────────────────────┘    │              │
# │  │                                         │              │
# │  │  Service Resources:                     │              │
# │  │  • ACR, KeyVault, CosmosDB, etc.       │              │
# │  └─────────────────────────────────────────┘              │
# └─────────────────────────────────────────────────────────────┘
# 
# Traffic flow:
# 1. App in workload VNet resolves myacr.privatelink.azurecr.io
# 2. Query forwarded to Azure DNS (168.63.129.16)
# 3. Azure DNS checks Private DNS Zone (via VNet Link to hub)
# 4. Returns Private Endpoint IP (10.10.2.5)
# 5. App connects to ACR via Private Endpoint in local VNet
# 
# ===================================================================
