resource "azurerm_resource_group" "redisent-rg" {
  location = local.primary_region
  name     = "redis-enterprise-rg"
  tags     = local.tags
}

resource "random_string" "postfix" {
  length  = 4
  upper   = false
  special = false
}
