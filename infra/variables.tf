// Variables for APIM Landing Zone

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "apim_name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for APIM endpoints (e.g., thefoggi.com)"
  type        = string
}

variable "api_hostname" {
  description = "Hostname for APIM proxy endpoint (e.g., api.thefoggi.com)"
  type        = string
}

variable "portal_hostname" {
  description = "Hostname for APIM developer portal (e.g., portal.thefoggi.com)"
  type        = string
}

variable "management_hostname" {
  description = "Hostname for APIM management endpoint (e.g., management.thefoggi.com)"
  type        = string
}

variable "certificate_pfx_path" {
  description = "Path to the wildcard PFX certificate file"
  type        = string
  default     = "../certificate/wildcard.thefoggi.com.pfx"
}

variable "certificate_password" {
  description = "Password for the PFX certificate file"
  type        = string
  sensitive   = true
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault to store the certificate"
  type        = string
  default     = "apimlz-kv"
}
