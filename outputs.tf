output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}

output "vm_private_ips" {
  value = {
    for key, nic in azurerm_network_interface.nic :
    key => nic.private_ip_address
  }
}