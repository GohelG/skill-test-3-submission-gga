#====================================================================================
# Network - main.tf
#====================================================================================

resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name

tags = {
    Environment = "skill-test-three"
  }
  
}

resource "azurerm_subnet" "private_subnet" {
  name                 = "private-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.private_subnet_cidr]
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.public_subnet_cidr]
}

resource "azurerm_route_table" "route_table" {
  name                = "my-route-table"
  location            = var.location
  resource_group_name = var.resource_group_name

  route {
    name                   = "default-route"
    address_prefix         = "0.0.0/0"
    next_hop_type          = "Internet"
    }
}

resource "azurerm_subnet_route_table_association" "private_subnet_association" {
  subnet_id      = azurerm_subnet.private_subnet.id
  route_table_id = azurerm_route_table.route_table.id
}

resource "azurerm_subnet_route_table_association" "public_subnet_association" {
  subnet_id      = azurerm_subnet.public_subnet.id
  route_table_id = azurerm_route_table.route_table.id
}