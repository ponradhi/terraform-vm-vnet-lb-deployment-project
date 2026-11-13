# 1. RESOURCE GROUP

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. VIRTUAL NETWORK

resource "azurerm_virtual_network" "vnet" {

  name = "vnet-terraform-project"

  location = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

  address_space = ["10.10.0.0/16"]

}
# 3. SUBNET

resource "azurerm_subnet" "subnet" {

  name = "snet-web"

  resource_group_name = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = ["10.10.1.0/24"]

}

# 4. NETWORK SECURITY GROUP

resource "azurerm_network_security_group" "nsg" {

  name = "nsg-terraform-web"

  location = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name = "Allow-HTTP"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "Allow-LB-Probe"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "Allow-Password-Login"
    priority = 120
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = var.admin_ip_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {

  subnet_id = azurerm_subnet.subnet.id

  network_security_group_id = azurerm_network_security_group.nsg.id

}

# 5. PUBLIC IP

resource "azurerm_public_ip" "lb_pip" {

  name = "pip-terraform-lb"

  location = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"

  sku = "Standard"

}

# 6. LOAD BALANCER

resource "azurerm_lb" "lb" {

  name = "lb-terraform-project"

  location = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

  sku = "Standard"

  frontend_ip_configuration {

    name = "public"

    public_ip_address_id = azurerm_public_ip.lb_pip.id

  }
}

# 7. LOAD BALANCER BACKEND ADDRESS POOL

resource "azurerm_lb_backend_address_pool" "backend" {

  name = "backend-pool"

  loadbalancer_id = azurerm_lb.lb.id

}

# 8. LOAD BALANCER HEALTH PROBE

resource "azurerm_lb_probe" "http" {

  name = "http-health-probe"

  loadbalancer_id = azurerm_lb.lb.id

  protocol = "Http"

  port = 80

  request_path = "/"

}

# 9. LOAD BALANCER RULE

resource "azurerm_lb_rule" "http" {

  name = "http-rule"

  loadbalancer_id = azurerm_lb.lb.id

  protocol = "Tcp"

  frontend_port = 80

  backend_port = 80

  frontend_ip_configuration_name = "public"

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.backend.id
  ]

  probe_id = azurerm_lb_probe.http.id

  disable_outbound_snat = true

  tcp_reset_enabled = true

}

# 10. LOAD BALANCER OUTBOUND RULE

resource "azurerm_lb_outbound_rule" "outbound" {

  name = "vm-outbound-rule"

  loadbalancer_id = azurerm_lb.lb.id

  protocol = "All"

  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id

  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = "public"
  }
}

# 11. LOAD BALANCER NAT RULES

resource "azurerm_lb_nat_rule" "ssh" {

  for_each = toset(["01", "02"])

  name = "vm-${each.key}-password-access"

  resource_group_name = azurerm_resource_group.rg.name

  loadbalancer_id = azurerm_lb.lb.id

  protocol = "Tcp"

  frontend_port = each.key == "01" ? 50001 : 50002

  backend_port = 22

  frontend_ip_configuration_name = "public"

}

# 12. NETWORK INTERFACE

resource "azurerm_network_interface" "nic" {
  for_each = toset(["01", "02"])

  name                = "nic-web-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"

    primary = true

  }
}
  resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_assoc" {
  for_each = toset(["01", "02"])

  network_interface_id    = azurerm_network_interface.nic[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id
}


  

# 13. LINUX VIRTUAL MACHINE

resource "azurerm_linux_virtual_machine" "vm" {

  for_each = toset(["01", "02"])

  name = "vm-web-${each.key}"

  computer_name = "web${each.key}"

  resource_group_name = azurerm_resource_group.rg.name

  location = azurerm_resource_group.rg.location

  size = var.vm_size
  # Network connecton

    network_interface_ids = [
    azurerm_network_interface.nic[each.key].id
  ]

 # Username and password
  admin_username = var.vm_admin_username

  admin_password = var.vm_admin_password

  disable_password_authentication = false

  
# Operating system disk
  os_disk {

    name = "osdisk-web-${each.key}"

    caching = "ReadWrite"

    storage_account_type = "StandardSSD_LRS"

  }
 # Ubuntu operating system

  source_image_reference {

    publisher = "Canonical"

    offer = "0001-com-ubuntu-server-jammy"

    sku = "22_04-lts-gen2"

    version = "latest"

  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "Welcome to Student Portal - Server ${each.key}" > /var/www/html/index.html
    systemctl enable nginx
    systemctl restart nginx
  EOF
  )

  tags = {
    Environment = "Terraform-Practice"
    Project     = "VM-LB"
  }

}
