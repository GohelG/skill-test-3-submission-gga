#====================================================================================
# Root - variable.tf
#====================================================================================

variable "location" {
  description = "The target Azure region for the resources."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "skill-test-three-rg"
}

variable "vnet_cidr" {
  description = "The CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "vm_size" {
  description = "The size of the virtual machine."
  type        = string
  default     = "Standard_B1s"
}

variable "vm_admin_username" {
  description = "The admin username for the virtual machine."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "The SSH public key for the virtual machine."
  type        = string
  default     = "C:/Users/gautam.gohil/Downloads/multicloud-key/ssh-key-rg.pem"
}
