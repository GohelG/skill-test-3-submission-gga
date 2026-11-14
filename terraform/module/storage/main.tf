#====================================================================================
# Storage - main.tf
#====================================================================================

resource "random_string" "storage_account_name" {
  length  = 7
  special = false
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "skilltest3${random_string.storage_account_name.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
 
  tags = {
    Environment = "skill-test-three"
  }

}

resource "azurerm_storage_container" "storage_container" {
  name                  = "skilltest3-container"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "blob"
}