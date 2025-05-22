resource "azurerm_redis_enterprise_cluster" "redisent-primary" {
  name                = "${local.prefix}-primary"
  resource_group_name = azurerm_resource_group.redisent-rg.name
  location            = local.primary_region

  sku_name = "Enterprise_E5-2"
  depends_on = [
    module.redis-private-dns-zone,
    # module.redis-private-dns-zone.azurerm_private_dns_zone_virtual_network_link.this["primary"],
    # module.redis-private-dns-zone.azurerm_private_dns_zone_virtual_network_link.this["secondary"],
    # module.redis-private-dns-zone.azurerm_private_dns_zone_virtual_network_link.this["agent"],
    module.redisent-vnet-primary,
    module.redisent-vnet-secondary
    # module.redisent-vnet-primary.module.peering["${local.prefix}-vnet-primary-to-agent"].azapi_resource.this[0],
    # module.redisent-vnet-primary.module.peering["${local.prefix}-vnet-primary-to-agent"].azapi_resource.reverse[0],
    # module.redisent-vnet-secondary.module.peering["${local.prefix}-vnet-secondary-to-agent"].azapi_resource.this[0],
    # module.redisent-vnet-secondary.module.peering["${local.prefix}-vnet-secondary-to-agent"].azapi_resource.reverse[0],
    # module.redisent-vnet-secondary.module.peering["primary-to-secondary"].azapi_resource.this[0],
    # module.redisent-vnet-secondary.module.peering["primary-to-secondary"].azapi_resource.reverse[0],
  ]
}

resource "azurerm_private_endpoint" "redisent-pe-primary" {
  name                = "${local.prefix}-pe-primary"
  location            = local.primary_region
  resource_group_name = azurerm_resource_group.redisent-rg.name

  subnet_id = module.redisent-vnet-primary.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "${local.prefix}-psc-primary"
    private_connection_resource_id = azurerm_redis_enterprise_cluster.redisent-primary.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.prefix}-pe-primary"
    private_dns_zone_ids = [module.redis-private-dns-zone.resource_id]
  }
}

resource "azurerm_redis_enterprise_cluster" "redisent-secondary" {
  name                = "${local.prefix}-secondary"
  resource_group_name = azurerm_resource_group.redisent-rg.name
  location            = local.secondary_region

  sku_name = "Enterprise_E5-2"
}

resource "azurerm_private_endpoint" "redisent-pe-secondary" {
  name                = "${local.prefix}-pe-secondary"
  location            = local.secondary_region
  resource_group_name = azurerm_resource_group.redisent-rg.name

  subnet_id = module.redisent-vnet-secondary.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "${local.prefix}-psc-secondary"
    private_connection_resource_id = azurerm_redis_enterprise_cluster.redisent-secondary.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.prefix}-pe-secondary"
    private_dns_zone_ids = [module.redis-private-dns-zone.resource_id]
  }
}

resource "azurerm_redis_enterprise_database" "default-primary" {
  name              = "default"
  cluster_id        = azurerm_redis_enterprise_cluster.redisent-primary.id
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  module {
    name = "RediSearch"
  }
  module {
    name = "RedisJSON"
  }
  linked_database_id = [
    "${azurerm_redis_enterprise_cluster.redisent-primary.id}/databases/default",
    "${azurerm_redis_enterprise_cluster.redisent-secondary.id}/databases/default"
  ]

  linked_database_group_nickname = "${local.prefix}GeoGroup"
}

resource "azurerm_redis_enterprise_database" "default-secondary" {
  name              = "default"
  cluster_id        = azurerm_redis_enterprise_cluster.redisent-secondary.id
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  module {
    name = "RediSearch"
  }
  module {
    name = "RedisJSON"
  }
  linked_database_id = [
    "${azurerm_redis_enterprise_cluster.redisent-primary.id}/databases/default",
    "${azurerm_redis_enterprise_cluster.redisent-secondary.id}/databases/default"
  ]

  linked_database_group_nickname = "${local.prefix}GeoGroup"
}
