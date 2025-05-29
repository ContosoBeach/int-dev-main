module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.2"

  availability_zones_filter = true
  useuse_cached_data        = false
}

resource "random_string" "postfix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this-rg" {
  location = var.region
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}
