locals {
  redisent_vnets = {
    primary = {
      name                 = "${local.prefix}-vnet-primary"
      address_space        = ["10.1.0.0/16"]
      subnet1_space        = ["10.1.0.0/24"]
      subnet2_space        = ["10.1.1.0/24"]
      location             = local.primary_region
      peering_name         = "${local.prefix}-vnet-primary-to-agent"
      peering_reverse_name = "agent-to-${local.prefix}-vnet-primary"
    }
    secondary = {
      name                 = "${local.prefix}-vnet-secondary"
      address_space        = ["10.2.0.0/16"]
      subnet1_space        = ["10.2.0.0/24"]
      subnet2_space        = ["10.2.1.0/24"]
      location             = local.secondary_region
      peering_name         = "${local.prefix}-vnet-secondary-to-agent"
      peering_reverse_name = "agent-to-${local.prefix}-vnet-secondary"
    }
  }
}


data "azurerm_virtual_network" "agent-vnet" {
  name                = "vnet-int-dev-scus-001"
  resource_group_name = "rg-int-agents-dev-scus-001"
}


module "redisent-vnets" {
  for_each            = local.redisent_vnets
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  address_space       = each.value.address_space
  location            = each.value.location
  name                = each.value.name
  resource_group_name = azurerm_resource_group.redisent-rg.name
  subnets = {
    "subnet1" = {
      name             = "default"
      address_prefixes = each.value.subnet1_space
    }
    "subnet2" = {
      name             = "redis-subnet"
      address_prefixes = each.value.subnet2_space
    }
  }
  peerings = {
    "peering-${each.key}" = {
      name                                 = each.value.peering_name
      remote_virtual_network_resource_id   = data.azurerm_virtual_network.agent-vnet.id
      allow_virtual_network_access         = true
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = each.value.peering_reverse_name
      reverse_allow_virtual_network_access = true
      reverse_allow_forwarded_traffic      = true
      reverse_allow_gateway_transit        = false
      reverse_use_remote_gateways          = false

    }
  }
  tags = local.tags
}


module "redis-private-dns-zone" {
  source              = "Azure/avm-res-network-privatednszone/azurerm"
  version             = "0.3.3"
  domain_name         = "privatelink.redisenterprise.cache.azure.net"
  resource_group_name = azurerm_resource_group.redisent-rg.name
  virtual_network_links = {
    "primary" = {
      vnetlinkname = "${local.prefix}-vnet-primary"
      vnetid       = module.redisent-vnets["primary"].resource_id
    }
    "secondary" = {
      vnetlinkname = "${local.prefix}-vnet-secondary"
      vnetid       = module.redisent-vnets["secondary"].resource_id
    }
    "agent" = {
      vnetlinkname = "agent-vnet"
      vnetid       = data.azurerm_virtual_network.agent-vnet.id
    }
  }
}
