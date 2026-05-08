# naming convention:
## Resource Group
    rg-{projectName}-{AREAS: app/data/network}-{env}-001

    AREAS:
        {app}
        - azure-aks
        - azure-keyvault
        - azure-vm
        - azure-acr


        {data}
        - azure-cosmosdb
        - azure-redis

        {network}
        - vNetwork
        - PrivateEndpoint(s)

## Service Name:
azure-aks = aks-{projectName}-{environment}-001
azure-redis = redis-{projectName}-{environment}-001
azure-keyvault = akv-{projectName}-{environment}-001
azure-cosmos = cosmos-{projectName}-{environment}-001
azure-acr = acr{projectName}{environment}001

## vNetwork Name
vnet-{projectName}-{environmentName}-apse-001



