#====================================================================================
# Network - output.tf
#====================================================================================
output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "private_subnet_id" {
  value = azurerm_subnet.private_subnet.id
}

output "public_subnet_id" {
  value = azurerm_subnet.public_subnet.id
}
