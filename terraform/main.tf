#====================================================================================
# Root - main.tf
#====================================================================================

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type    = string
  default = "C:/Users/gautam.gohil/Downloads/multicloud-key/azure_vm_key.pub"
}

locals {
  ssh_public_key_content = trimspace(file(var.ssh_public_key_path))
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Module for Network
module "network" {
  source              = "./module/network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
}

# Module for Security
module "security" {
  source              = "./module/security"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# Module for Storage
module "storage" {
  source              = "./module/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# Module for VM
module "vm" {
  source              = "./module/vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = module.network.private_subnet_id
  nsg_id              = module.security.nsg_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key_content
}

# Azure Standard Load Balancer (ALB)
resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-load-balancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "alb" {
  name                = "alb-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id = azurerm_lb.alb.id
  name            = "bepool-web"
}

resource "azurerm_lb_probe" "hp" {
  loadbalancer_id = azurerm_lb.alb.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.alb.id
  name                           = "LBRule-HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                       = azurerm_lb_probe.hp.id
}

# Virtual Machine Scale Set (ASG Equivalent: 2 to 4 instances)
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-web"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vm_size
  instances           = 2
  admin_username      = var.admin_username
  zones               = ["1", "2"]

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_public_key_content
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-vmss"
    primary = true
    ip_configuration {
      name                                   = "ipconfig-vmss"
      primary                                = true
      subnet_id                              = module.network.public_subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool.id]
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              systemctl enable apache2
              systemctl start apache2
              echo "<h1>VMSS Instance: $(hostname)</h1>" > /var/www/html/index.html
              EOF
  )
}

# Auto-scaling Settings (Scale out when CPU > 70%)
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale-cpu-rule"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"
    capacity {
      default = 2
      minimum = 2
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
