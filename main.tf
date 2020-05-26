provider "azurerm" {
  version = "=2.8.0"
  features {}
}

locals {
    resource_location = "australiaeast"
}

variable "environment_subnets" {
    type = list
    default = ["public", "application", "data"]
}

variable "VMSize_map" {
    type = map
    default = {
        "development" = "Standard_A1_v2"
        "staging" = "Standard_A2_v2"
        "production" = "Standard_A4_v2"
    }
}

resource "random_password" "vmpassword" {
    length = 16
    special = true
    min_special = 5
}


#create the resource group
resource "azurerm_resource_group" "rg" {
    name = "ateam-resource-group"
    location = local.resource_location
}

#create the virtual network
resource "azurerm_virtual_network" "vnet1" {
    resource_group_name = azurerm_resource_group.rg.name
    location = local.resource_location
    name = "dev"
    address_space = ["10.0.0.0/16"]
}

#create a subnet within the virtual network
resource "azurerm_subnet" "subnet1" {
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet1.name
    name = var.environment_subnets[0]
    address_prefixes = ["10.0.0.0/24"]
}

##create the network interface for the VM
resource "azurerm_public_ip" "pub_ip" {
    name = "vmpubip"
    location = local.resource_location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "vmnic" {
    location = local.resource_location
    resource_group_name = azurerm_resource_group.rg.name
    name = "vmnic1"

    ip_configuration {
        name = "vmnic1-ipconf"
        subnet_id = azurerm_subnet.subnet1.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.pub_ip.id
    }
}

##end creating network interface for the VM


##create the actual VM
resource "azurerm_windows_virtual_machine" "devvm" {
    name = "development-vm"
    location = local.resource_location
    size = var.VMSize_map["development"]
    admin_username = "pradeep"
    admin_password = random_password.vmpassword.result
    resource_group_name = azurerm_resource_group.rg.name

    network_interface_ids = [azurerm_network_interface.vmnic.id]
    
    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2016-Datacenter"
        version = "latest"
    }

}
##end creating VM
data "azurerm_public_ip" "vmip" {
    name = azurerm_public_ip.pub_ip.name
    resource_group_name = azurerm_windows_virtual_machine.devvm.resource_group_name
}

output "generated_password" {
    value = random_password.vmpassword.result
}

output "public_ip_address" {
    value = data.azurerm_public_ip.vmip
}


