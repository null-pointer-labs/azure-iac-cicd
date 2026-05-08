# naming convention:
## Resource Group
    rg-{projectName}-{AREAS: app/data/network}-{env}-001

    AREAS:
        {app}
        - azure-aks (has dedicated resource group but subnet in network RG)
        - azure-keyvault
        - azure-vm
        - azure-acr


        {data}
        - azure-cosmosdb
        - azure-redis

        {network}
        - vNetwork (/22 CIDR - 1024 IPs)
        - Subnets:
          * snet-app (/26 - 64 IPs) - App services Private Endpoints
          * snet-data (/26 - 64 IPs) - Data services Private Endpoints
          * snet-aks (/23 - 512 IPs) - AKS nodes (conditional, only if AKS selected)

## Network Configuration
vNet Address Space: /22 (e.g., 172.16.200.0/22)

Subnet Allocation:
- snet-app:  172.16.200.0/26   (64 IPs)   - ACR, KeyVault, VM Private Endpoints
- snet-data: 172.16.200.64/26  (64 IPs)   - CosmosDB, Redis Private Endpoints
- snet-aks:  172.16.202.0/23   (512 IPs)  - AKS node pool (only if AKS module selected)

## Service Name:
azure-aks = aks-{projectName}-{environment}-001
azure-redis = redis-{projectName}-{environment}-001
azure-keyvault = akv-{projectName}-{environment}-001
azure-cosmos = cosmos-{projectName}-{environment}-001
azure-acr = acr{projectName}{environment}001

## vNetwork Name
vnet-{projectName}-{environmentName}-apse-001

## Subnet Names
snet-{projectName}-{environmentName}-app   # App services
snet-{projectName}-{environmentName}-data  # Data services
snet-{projectName}-{environmentName}-aks   # AKS nodes (conditional)



