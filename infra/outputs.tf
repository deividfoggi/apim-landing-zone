// Outputs for APIM Landing Zone

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "apim_name" {
  value = azurerm_api_management.apim.name
}

output "apim_private_ip" {
  value = azurerm_api_management.apim.private_ip_addresses[0]
}

output "appgw_public_ip" {
  value = azurerm_public_ip.appgw_pip.ip_address
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "appgw_frontend_fqdn" {
  value = azurerm_public_ip.appgw_pip.fqdn
}

output "api_dns_record" {
  value = "CNAME record: api.${var.custom_domain} -> ${azurerm_public_ip.appgw_pip.fqdn != null ? azurerm_public_ip.appgw_pip.fqdn : azurerm_public_ip.appgw_pip.ip_address}"
}

output "portal_dns_record" {
  value = "CNAME record: portal.${var.custom_domain} -> ${azurerm_public_ip.appgw_pip.fqdn != null ? azurerm_public_ip.appgw_pip.fqdn : azurerm_public_ip.appgw_pip.ip_address}"
}

output "management_dns_record" {
  value = "CNAME record: management.${var.custom_domain} -> ${azurerm_public_ip.appgw_pip.fqdn != null ? azurerm_public_ip.appgw_pip.fqdn : azurerm_public_ip.appgw_pip.ip_address}"
}
