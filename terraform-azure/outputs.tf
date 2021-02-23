output "es_image_id" {
  value = data.azurerm_image.presto.name
}

output "kibana_image_id" {
  value = data.azurerm_image.presto-client.name
}

output "clients_public_dns" {
  value = azurerm_public_ip.clients.*.fqdn
}

output "clients_public_ip_address" {
  value = azurerm_public_ip.clients.*.ip_address
}

output "public_dns" {
  value = azurerm_public_ip.coordinator.*.fqdn
}

output "public_ip_address" {
  value = azurerm_public_ip.coordinator.*.ip_address
}


output "vm_password" {
  value = random_string.vm-login-password.result
}


output "clients_password" {
  value = random_string.clients-admin-password[0].result
}
