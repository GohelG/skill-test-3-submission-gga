#===============================================================================================
# Root - terraform.tfvars (For demo purposes only; add to .gitignore in production for security)
# ===============================================================================================
location            = "eastus"
resource_group_name = "skill-test-three-rg"
vnet_cidr           = "10.0.0.0/16"
private_subnet_cidr = "10.0.1.0/24"
public_subnet_cidr  = "10.0.2.0/24"
vm_size             = "Standard_B1s"
vm_admin_username   = "azureuser"
ssh_public_key      = "C:/Users/gautam.gohil/Downloads/multicloud-key/ssh-key-rg.pem"
