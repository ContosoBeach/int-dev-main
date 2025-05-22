locals {
  redis-cluster = {
    primary = {
      name          = "${local.prefix}-primary"
      location      = local.primary_region
      database_name = "default"
    }
    secondary = {
      name          = "${local.prefix}-secondary"
      location      = local.secondary_region
      database_name = "default"
    }
  }
}


resource "azurerm_redis_enterprise_cluster" "redisent-cluster" {
  for_each            = local.redis-cluster
  name                = each.value.name
  resource_group_name = azurerm_resource_group.redisent-rg.name
  location            = each.value.location

  sku_name = "Enterprise_E5-2"
}

resource "azurerm_redis_enterprise_database" "default-databases" {
  for_each          = local.redis-cluster
  name              = each.value.database_name
  cluster_id        = azurerm_redis_enterprise_cluster.redisent-cluster[each.key].id
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  module {
    name = "RediSearch"
  }
  module {
    name = "RedisJSON"
  }
  linked_database_id = [
    format("%s/%s", azurerm_redis_enterprise_cluster.redisent-cluster["primary"].id, "databases/${each.value.database_name}"),
    format("%s/%s", azurerm_redis_enterprise_cluster.redisent-cluster["secondary"].id, "databases/${each.value.database_name}"),
  ]

  linked_database_group_nickname = "${local.prefix}GeoGroup"
}

resource "azurerm_private_endpoint" "redisent-pes" {
  for_each            = local.redis-cluster
  name                = "${local.prefix}-pe-${each.key}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.redisent-rg.name

  subnet_id = module.redisent-vnets["${each.key}"].subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "${local.prefix}-psc-${each.key}"
    private_connection_resource_id = azurerm_redis_enterprise_cluster.redisent-cluster["${each.key}"].id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.prefix}-pe-${each.key}"
    private_dns_zone_ids = [module.redis-private-dns-zone.resource_id]
  }
  depends_on = [
    module.redis-private-dns-zone,
    module.redisent-vnets,
    azurerm_redis_enterprise_database.default-databases
  ]
}
