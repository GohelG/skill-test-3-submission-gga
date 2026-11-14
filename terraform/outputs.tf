#====================================================================================
# Root - outputs.tf
#====================================================================================

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "vm_public_ip" {
  value = module.vm.vm_public_ip
}

output "vm_private_ip" {
  value = module.vm.vm_private_ip
}

output "vnet_id" {
  value = module.network.vnet_id
}
