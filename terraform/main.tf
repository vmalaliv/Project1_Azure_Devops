provider "azurerm" {
  features {}
}

#locate the existing resource group
data "azurerm_resource_group" "main"{
  name     = "${var.prefix}-RG"  
} 


#create virtual network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-Vnetwork"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  
  tags = {
    environment = "${var.prefix}"
  }
}

#create subnet
resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

}

#create a public IP
resource "azurerm_public_ip" "main" {
  count = length("${var.vm_names}")
  name                = "${var.prefix}-my-public-ip-${var.vm_names[count.index]}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    environment = "${var.prefix}"
  }
}

#create a second public IP for Load Balancer
resource "azurerm_public_ip" "main2" {
  name                = "${var.prefix}-my-public-ip-LB"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    environment = "${var.prefix}"
  }
}

#create network interface
resource "azurerm_network_interface" "main" {
  count = length("${var.vm_names}")
  name                = "${var.prefix}-nic-${var.vm_names[count.index]}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id 
  }

  tags = {
    environment = "${var.prefix}"
  }
}

#create NSG - with allow and deny rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
  name                        = "AllowAccessToOtherVMs"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "3389"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  }

  security_rule {
  name                        = "DenyDirectAccessFromInet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  }

    tags = {
    environment = "${var.prefix}"
  }

}

#create Load Balancer
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-LoadBalancer"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main2.id
  }

    tags = {
    environment = "${var.prefix}"
  }
}

#create Load Balancer backend address pool 
resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "BackEndAddressPool"
}

#locate the existing custom image
data "azurerm_image" "main" {
  name    = "${var.prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
}

#create virtual machine (using for_each)
resource "azurerm_virtual_machine" "main" {
  count = length("${var.vm_names}")
  
  name                            = "${var.prefix}-${var.vm_names[count.index]}"
  resource_group_name              = data.azurerm_resource_group.main.name
  location                         = data.azurerm_resource_group.main.location
  network_interface_ids = [azurerm_network_interface.main[count.index].id,]
  vm_size               = "Standard_F2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.main.id}"
  }

  os_profile_linux_config{
    disable_password_authentication = false
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }


  storage_os_disk {
    name              = "osdisk-${var.vm_names[count.index]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

    tags = {
    environment = "${var.prefix}"
  }
}

resource "azurerm_managed_disk" "main" {
  name                 = "${var.prefix}-md"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  tags = {
    environment = "${var.prefix}"
  }
}