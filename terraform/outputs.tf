output "vm_public_ip" {
  description = "Public IP address of MiniSOC VM"
  value       = azurerm_public_ip.minisoc.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of MiniSOC VM"
  value       = azurerm_network_interface.minisoc.private_ip_address
}

output "vm_name" {
  description = "Name of MiniSOC VM"
  value       = azurerm_linux_virtual_machine.minisoc.name
}
