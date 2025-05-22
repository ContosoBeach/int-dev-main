data "azurerm_virtual_network" "agent-vnet" {
  name                = "vnet-int-dev-scus-001"
  resource_group_name = "rg-int-agents-dev-scus-001"
}


module "redisent-vnet-primary" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  address_space       = ["10.1.0.0/16"]
  location            = local.primary_region
  name                = "${local.prefix}-vnet-primary"
  resource_group_name = azurerm_resource_group.redisent-rg.name
  subnets = {
    "subnet1" = {
      name             = "default"
      address_prefixes = ["10.1.0.0/24"]
    }
    "subnet2" = {
      name             = "redis-subnet"
      address_prefixes = ["10.1.1.0/24"]
    }
  }
  peerings = {
    "redisent-vnet-primary-to-agent" = {
      name                                 = "${local.prefix}-vnet-primary-to-agent"
      remote_virtual_network_resource_id   = data.azurerm_virtual_network.agent-vnet.id
      allow_virtual_network_access         = true
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = "agent-to-${local.prefix}-vnet-primary"
      reverse_allow_virtual_network_access = true
      reverse_allow_forwarded_traffic      = true
      reverse_allow_gateway_transit        = false
      reverse_use_remote_gateways          = false

    }
  }
  tags = local.tags
}

module "redisent-vnet-secondary" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  address_space       = ["10.2.0.0/16"]
  location            = local.secondary_region
  name                = "${local.prefix}-vnet-secondary"
  resource_group_name = azurerm_resource_group.redisent-rg.name
  subnets = {
    "subnet1" = {
      name             = "default"
      address_prefixes = ["10.2.0.0/24"]
    }
    "subnet2" = {
      name             = "redis-subnet"
      address_prefixes = ["10.2.1.0/24"]
    }
  }
  peerings = {
    "redisent-vnet-secondary-to-agent" = {
      name                                 = "${local.prefix}-vnet-secondary-to-agent"
      remote_virtual_network_resource_id   = data.azurerm_virtual_network.agent-vnet.id
      allow_virtual_network_access         = true
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = "agent-to-${local.prefix}-vnet-secondary"
      reverse_allow_virtual_network_access = true
      reverse_allow_forwarded_traffic      = true
      reverse_allow_gateway_transit        = false
      reverse_use_remote_gateways          = false
    },
    "primary-to-secondary" = {
      name                                 = "secondary-to-primary"
      remote_virtual_network_resource_id   = module.redisent-vnet-primary.resource_id
      allow_virtual_network_access         = true
      allow_forwarded_traffic              = true
      allow_gateway_transit                = false
      use_remote_gateways                  = false
      create_reverse_peering               = true
      reverse_name                         = "primary-to-secondary"
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
      vnetid       = module.redisent-vnet-primary.resource_id
    }
    "secondary" = {
      vnetlinkname = "${local.prefix}-vnet-secondary"
      vnetid       = module.redisent-vnet-secondary.resource_id
    }
    "agent" = {
      vnetlinkname = "agent-vnet"
      vnetid       = data.azurerm_virtual_network.agent-vnet.id
    }
  }
}
