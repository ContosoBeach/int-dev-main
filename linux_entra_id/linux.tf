resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[var.region].zones)
  min = 1
}

module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = var.region
  cache_results = true

  vm_filters = {
    min_vcpus                      = 2
    max_vcpus                      = 2
    encryption_at_host_supported   = true
    accelerated_networking_enabled = true
    premium_io_supported           = true
    location_zone                  = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}

module "public-ip" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "0.2.0"

  resource_group_name = "azurerm_resource_group.this-rg.name"
  location            = "azurerm_resource_group.this-rg.location"
  name                = module.naming.public_ip_address.name_unique
}

module "linux-vms" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.1"

  location            = azurerm_resource_group.this-rg.location
  resource_group_name = azurerm_resource_group.this-rg.name
  os_type             = "Linux"
  name                = module.naming.virtual_machine.name_unique
  sku_size            = module.vm_sku.sku
  zone                = random_integer.zone_index.result

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  managed_identities = {
    system_assigned = true
  }

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = module.linux-vnets["primary"].subnets["subnet1"].resource_id
          public_ip_address_id          = module.public-ip.resource_id
        }
      }
    }
  }

  extensions = {
    "enable-entra-id" = {
      name                       = "AADSSHLoginForLinux"
      publisher                  = "Microsoft.Azure.ActiveDirectory"
      type                       = "AADSSHLoginForLinux"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
    }
  }

  tags = local.tags

}

module "avm-res-authorization-roleassignment" {
  source  = "Azure/avm-res-authorization-roleassignment/azurerm"
  version = "0.2.0"

  users_by_user_principal_name = {
    admin = var.admin_user_principal_name
  }

  role_definitions = {
    "Virtual Machine Administrator Login" = {
      name = "Virtual Machine Administrator Login"
    }
  }

  role_assignments_for_resource_groups = {
    this-group = {
      resource_group_name = azurerm_resource_group.this-rg.name
      role_assignments = {
        "admin" = {
          role_definition = "Virtual Machine Administrator Login"
          users           = ["admin"]
        }
      }
    }
  }
}
