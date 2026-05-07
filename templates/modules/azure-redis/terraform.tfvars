
# ===================================================================
# Azure Redis Cache Configuration
# ===================================================================
# Standard SKU C3 (2.5 GB memory) with Private Endpoint and replication
redis_name                    = "redis-__PROJECT_NAME__-__ENV_NAME__" # Must be globally unique
redis_sku_name                = "Standard"                             # Standard = SLA with replication, supports Private Endpoint
redis_family                  = "C"                                    # C = Basic/Standard family
redis_capacity                = 3                                      # 3 = 2.5GB cache size (C3 tier)
redis_enable_private_endpoint = true                                   # Enable Private Endpoint for secure VNet-only access
