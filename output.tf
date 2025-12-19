output "vm_consumer_private_ip" {
  description = "Private IP of VM Consumer"
  value       = azurerm_network_interface.consumer_nic.ip_configuration[0].private_ip_address
}

output "vm_consumer_public_ip" {
  description = "Public IP of VM Consumer"
  value       = azurerm_public_ip.consumer_pip.ip_address
}

output "vm_provider_private_ip" {
  description = "Private IP of VM Provider (Backend)"
  value       = azurerm_network_interface.provider_nic.ip_configuration[0].private_ip_address
}

output "vm_provider_public_ip" {
  description = "Public IP of VM Provider"
  value       = azurerm_public_ip.provider_pip.ip_address
}

output "load_balancer_private_ip" {
  description = "Private IP of Load Balancer"
  value       = azurerm_lb.main.frontend_ip_configuration[0].private_ip_address
}

output "private_endpoint_ip" {
  description = "Private IP of Private Endpoint"
  value       = azurerm_private_endpoint.main.private_service_connection[0].private_ip_address
}

output "ssh_command_vm_consumer" {
  description = "SSH command to connect to VM Consumer"
  value       = "ssh -i ~/.ssh/consumer_vm_key consumer-user@${azurerm_public_ip.consumer_pip.ip_address}"
}

output "ssh_command_vm_provider" {
  description = "SSH command to connect to VM Provider"
  value       = "ssh -i ~/.ssh/provider_vm_key provider-user@${azurerm_public_ip.provider_pip.ip_address}"
}

output "test_command" {
  description = "Command to test Private Link connectivity from VM Consumer"
  value       = "curl http://${azurerm_private_endpoint.main.private_service_connection[0].private_ip_address}"
}

output "pls_resource_output" {
  value = module.azurerm_private_link_service.resource
  description = "The whole resource output of the Private Link Service"
}

output "alias" {
  value = module.azurerm_private_link_service.alias
  description = "The alias of the Private Link Service"
}