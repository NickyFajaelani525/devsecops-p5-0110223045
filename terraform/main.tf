# Membuat Virtual Network
resource "azurerm_virtual_network" "minisoc" {
  name                = "vnet-minisoc"
  location            = "Malaysia West"
  resource_group_name = data.azurerm_resource_group.minisoc.name

  address_space = ["10.0.0.0/16"]
}

# Membuat Subnet

resource "azurerm_subnet" "minisoc" {
  name                 = "subnet-minisoc"
  resource_group_name  = data.azurerm_resource_group.minisoc.name
  virtual_network_name = azurerm_virtual_network.minisoc.name

  address_prefixes = ["10.0.1.0/24"]
}

# Membuat IP Public

resource "azurerm_public_ip" "minisoc" {
  name                = "pip-minisoc"
  location            = "Malaysia West"
  resource_group_name = data.azurerm_resource_group.minisoc.name

  allocation_method = "Static"
  sku               = "Standard"
}

# Membuat Network Security Group (NSG) no rulle added

resource "azurerm_network_security_group" "minisoc" {
  name                = "nsg-minisoc"
  location            = "Malaysia West"
  resource_group_name = data.azurerm_resource_group.minisoc.name
}

# Membuat Network Interface (NIC)

resource "azurerm_network_interface" "minisoc" {
  name                = "nic-minisoc"
  location            = "Malaysia West"
  resource_group_name = data.azurerm_resource_group.minisoc.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.minisoc.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.minisoc.id
  }
}

# Membuat Rule SSH

resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"

  resource_group_name         = data.azurerm_resource_group.minisoc.name
  network_security_group_name = azurerm_network_security_group.minisoc.name
}

# Asosiasi NSG ke NIC

resource "azurerm_network_interface_security_group_association" "minisoc" {
  network_interface_id      = azurerm_network_interface.minisoc.id
  network_security_group_id = azurerm_network_security_group.minisoc.id
}

# Membuat Linux VM

resource "azurerm_linux_virtual_machine" "minisoc" {
  name                = "vm-minisoc"
  location            = "Malaysia West"
  resource_group_name = data.azurerm_resource_group.minisoc.name
  size                = "Standard_B2als_v2"

  admin_username = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.minisoc.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
