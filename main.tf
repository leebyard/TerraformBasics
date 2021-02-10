# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

### Create Resource Groups

resource "azurerm_resource_group" "rgne2" {
  name     = "RGNE2"
  location = "northeurope"
}

resource "azurerm_resource_group" "rgwe2" {
  name     = "RGWE2"
  location = "westeurope"
}


### Create Virtual Networks and first Subnets

resource "azurerm_virtual_network" "vnetne2" {
  name                = "vNet-ne2"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rgne2.location
  resource_group_name = azurerm_resource_group.rgne2.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "vNet-ne2-Subnet1"
  resource_group_name  = azurerm_resource_group.rgne2.name
  virtual_network_name = azurerm_virtual_network.vnetne2.name
  address_prefix       = "10.1.0.0/24"
}


resource "azurerm_virtual_network" "vnetwe2" {
  name                = "vNet-we2"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.rgwe2.location
  resource_group_name = azurerm_resource_group.rgwe2.name
}

resource "azurerm_subnet" "subnetwe2" {
  name                 = "vNet-we2-Subnet1"
  resource_group_name  = azurerm_resource_group.rgwe2.name
  virtual_network_name = azurerm_virtual_network.vnetwe2.name
  address_prefix       = "10.2.0.0/24"
}

### Set up peering between virtual networks

resource "azurerm_virtual_network_peering" "vnetne2_vnetwe2" {
  name                      = "vnetne2_vnetwe2"
  resource_group_name       = azurerm_resource_group.rgne2.name
  virtual_network_name      = azurerm_virtual_network.vnetne2.name
  remote_virtual_network_id = azurerm_virtual_network.vnetwe2.id
}

resource "azurerm_virtual_network_peering" "vnetwe2_vnetne2" {
  name                      = "vnetwe2_vnetne2"
  resource_group_name       = azurerm_resource_group.rgwe2.name
  virtual_network_name      = azurerm_virtual_network.vnetwe2.name
  remote_virtual_network_id = azurerm_virtual_network.vnetne2.id
}


### Create Public IPs

resource "azurerm_public_ip" "ne2vm1publicip" {
    name                         = "ne2vm1PublicIP"
    location                     = azurerm_resource_group.rgne2.location
    resource_group_name          = azurerm_resource_group.rgne2.name
    allocation_method            = "Dynamic"

}

resource "azurerm_public_ip" "we2vm1publicip" {
    name                         = "we2vm1PublicIP"
    location                     = azurerm_resource_group.rgwe2.location
    resource_group_name          = azurerm_resource_group.rgwe2.name
    allocation_method            = "Dynamic"
    
}


### Create Virtual NICS

resource "azurerm_network_interface" "ne2vm1" {
  name                = "ne2vm1-nic"
  location            = azurerm_resource_group.rgne2.location
  resource_group_name = azurerm_resource_group.rgne2.name

  ip_configuration {
    name                          = "vNet-ne2"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ne2vm1publicip.id
  }
}

resource "azurerm_network_interface" "we2vm1" {
  name                = "we2vm1-nic"
  location            = azurerm_resource_group.rgwe2.location
  resource_group_name = azurerm_resource_group.rgwe2.name

  ip_configuration {
    name                          = "vNet-we2"
    subnet_id                     = azurerm_subnet.subnetwe2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.we2vm1publicip.id

  }
}


### Create Network Security Groups

resource "azurerm_network_security_group" "ne2-nsg-ne2vm1" {
    name                = "ne2-nsg-ne2vm1"
    location            = azurerm_resource_group.rgne2.location
    resource_group_name = azurerm_resource_group.rgne2.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "we2-nsg-we2vm1" {
    name                = "we2-nsg-we2vm1"
    location            = azurerm_resource_group.rgwe2.location
    resource_group_name = azurerm_resource_group.rgwe2.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

### Create associations between NSGs and Interfaces

resource "azurerm_network_interface_security_group_association" "ne2nsgintassoc" {
    network_interface_id      = azurerm_network_interface.ne2vm1.id
    network_security_group_id = azurerm_network_security_group.ne2-nsg-ne2vm1.id
}
resource "azurerm_network_interface_security_group_association" "we2nsgintassoc" {
    network_interface_id      = azurerm_network_interface.we2vm1.id
    network_security_group_id = azurerm_network_security_group.we2-nsg-we2vm1.id
}




### Create VMs

resource "azurerm_linux_virtual_machine" "ne2vm1" {
  name                = "ne2vm1-machine"
  resource_group_name = azurerm_resource_group.rgne2.name
  location            = azurerm_resource_group.rgne2.location
  size                = "Standard_B1ls"
  disable_password_authentication = false
  admin_username      = "devops"
  admin_password      = "insecure4sure!!"
  network_interface_ids = [
    azurerm_network_interface.ne2vm1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer = "CentOS"
    sku = "8_2"
    version = "latest"
}
}


resource "azurerm_linux_virtual_machine" "we2vm1" {
  name                = "we2vm1-machine"
  resource_group_name = azurerm_resource_group.rgwe2.name
  location            = azurerm_resource_group.rgwe2.location
  size                = "Standard_B1ls"
  disable_password_authentication = false
  admin_username      = "devops"
  admin_password      = "insecure4sure!!"
  network_interface_ids = [
    azurerm_network_interface.we2vm1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer = "CentOS"
    sku = "8_2"
    version = "latest"
}
}
