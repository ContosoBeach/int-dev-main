locals {
  linux_vnets = {
    primary = {
      name          = "${local.prefix}-vnet"
      address_space = ["10.1.0.0/16"]
      subnets = {
        subnet1 = {
          name  = "subnet1"
          space = ["10.1.0.0/24"]
        }
        subnet2 = {
          name  = "subnet2"
          space = ["10.1.1.0/24"]
        }
      }
      location             = var.region
      peering_name         = "${local.prefix}-vnet-to-agent"
      peering_reverse_name = "agent-to-${local.prefix}-vnet"
    }
  }
}

# data "azurerm_virtual_network" "agent-vnet" {
#   name                = "vnet-int-dev-scus-001"
#   resource_group_name = "rg-int-agents-dev-scus-001"
# }


module "linux-vnets" {
  for_each            = local.linux_vnets
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  address_space       = each.value.address_space
  location            = each.value.location
  name                = each.value.name
  resource_group_name = azurerm_resource_group.this-rg.name
  subnets = {
    for k, v in each.value.subnets :
    k => {
      name           = v.name
      address_prefix = v.space
      network_security_group = {
        id = module.network-networksecuritygroups["${each.value.name}-${v.name}-nsg"].resource_id
      }
    }
  }
  tags = local.tags
}

locals {
  vnet_subnets = flatten([
    for vnet_key, vnet in local.linux_vnets : [
      for subnet_key, subnet in vnet.subnets : {
        vnet_name   = vnet.name
        subnet_name = subnet.name
      }
    ]
  ])
  vnet_subnets_map = { for index, subnet in local.vnet_subnets : index => subnet }
}


module "network-networksecuritygroups" {
  source              = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version             = "0.4.0"
  for_each            = local.vnet_subnets_map
  name                = "${each.value.vnet_name}-${each.value.subnet_name}-nsg"
  resource_group_name = azurerm_resource_group.this-rg.name
  location            = azurerm_resource_group.this-rg.location
}
