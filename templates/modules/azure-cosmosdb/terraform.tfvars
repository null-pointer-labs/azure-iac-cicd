
# ===================================================================
# Azure Cosmos DB Configuration
# ===================================================================
# MongoDB API with autoscale provisioning (97K RU/s max)
# Single region write in Southeast Asia with analytical storage enabled
cosmosdb_account_name          = "cosmos-__PROJECT_NAME__-__ENV_NAME__"  # Must be globally unique, lowercase alphanumeric and hyphens
cosmosdb_throughput_mode       = "autoscale"                             # Autoscale: automatic scaling between 10%-100% of max throughput
cosmosdb_max_throughput        = 97000                                   # Maximum RU/s for autoscale (billed based on actual usage)
cosmosdb_mongo_server_version  = "6.0"                                   # MongoDB server version (6.0 is latest)
cosmosdb_enable_analytical_storage = true                                # Enable analytical storage for HTAP scenarios (adds columnar storage)
cosmosdb_backup_type           = "Periodic"                              # Periodic backup (scheduled snapshots)
cosmosdb_backup_interval_minutes = 240                                   # Backup every 4 hours (240 minutes)
cosmosdb_backup_retention_hours = 720                                    # Retain backups for 30 days (720 hours)
cosmosdb_backup_storage_redundancy = "Geo"                               # Geo-redundant backup storage (2 copies in paired region)
cosmosdb_enable_private_endpoint = true                                  # Enable Private Endpoint for secure VNet-only access
cosmosdb_public_network_access_enabled = false                           # Disable public access - VNet-only via Private Endpoint
