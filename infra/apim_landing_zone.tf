// APIM Landing Zone core resources

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.apim_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "apim" {
  name                 = "apim-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

// Application Gateway, NSGs, APIM, and other resources will be added here

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  
  # Enable RBAC authorization for modern access control
  enable_rbac_authorization = true
  
  # Temporarily disable network ACLs for testing
  # network_acls {
  #   default_action = "Allow"
  #   bypass         = "AzureServices"
  # }
}

data "azurerm_client_config" "current" {}

# RBAC role assignments for Key Vault management
resource "azurerm_role_assignment" "current_user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_certificate" "wildcard" {
  name         = "wildcard-thefoggi-com"
  key_vault_id = azurerm_key_vault.kv.id
  certificate {
    contents = filebase64(var.certificate_pfx_path)
    password = var.certificate_password
  }
  depends_on = [
    azurerm_key_vault.kv,
    azurerm_role_assignment.current_user_kv_admin
  ]
}

# RBAC role assignments for APIM Key Vault access
resource "azurerm_role_assignment" "apim_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

resource "azurerm_role_assignment" "apim_kv_certificate_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# Use RBAC role assignment instead of access policy for Application Gateway
resource "azurerm_role_assignment" "appgw_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

resource "azurerm_role_assignment" "appgw_kv_certificate_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

resource "azurerm_network_security_group" "apim_nsg" {
  name                = "${var.apim_name}-apim-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Required for APIM management endpoint access
  security_rule {
    name                       = "Management_endpoint_for_Azure_portal_and_Powershell"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Dependency_on_Redis_Cache"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6381-6383"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Dependency_to_sync_Rate_Limit_Inbound"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4290"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Dependency_on_Azure_SQL"
    priority                   = 1040
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Sql"
  }

  security_rule {
    name                       = "Dependency_for_Log_to_event_Hub_policy"
    priority                   = 1050
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5671"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "EventHub"
  }

  security_rule {
    name                       = "Dependency_on_Redis_Cache_outbound"
    priority                   = 1060
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6381-6383"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Depenedency_To_sync_RateLimit_Outbound"
    priority                   = 1070
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4290"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Dependency_on_Azure_File_Share_for_GIT"
    priority                   = 1080
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "Azure_Infrastructure_Load_Balancer"
    priority                   = 1090
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Publish_DiagnosticLogs_And_Metrics"
    priority                   = 1100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1886", "443"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureMonitor"
  }

  security_rule {
    name                       = "Connect_To_SMTP_Relay_For_SendingEmails"
    priority                   = 1110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["25", "587", "25028"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "Authenticate_To_Azure_Active_Directory"
    priority                   = 1120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureActiveDirectory"
  }

  security_rule {
    name                       = "Dependency_on_Azure_Storage"
    priority                   = 1130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "Access_KeyVault"
    priority                   = 1140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }
}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "${var.apim_name}-appgw-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Required for Application Gateway
  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHealthProbes"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim_assoc" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "appgw_assoc" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "${var.apim_name}-appgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.apim_name}-appgw"
}

# Wait for RBAC role assignments to propagate
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.appgw_kv_certificate_user,
    azurerm_role_assignment.appgw_kv_secrets_user
  ]
  create_duration = "60s"
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  depends_on = [
    time_sleep.wait_for_rbac,
    azurerm_role_assignment.appgw_kv_secrets_user,
    azurerm_role_assignment.appgw_kv_certificate_user
  ]
  name                = "${var.apim_name}-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }
  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = azurerm_subnet.appgw.id
  }
  frontend_ip_configuration {
    name                 = "frontendIP"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }
  frontend_port {
    name = "httpsPort"
    port = 443
  }
  ssl_certificate {
    name     = "wildcardCert"
    key_vault_secret_id = azurerm_key_vault_certificate.wildcard.secret_id
  }
  backend_address_pool {
    name  = "apimBackend"
    ip_addresses = [azurerm_api_management.apim.private_ip_addresses[0]]
  }
  probe {
    name                = "apiProbe"
    protocol            = "Https"
    host                = var.api_hostname
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200-399", "404"]
    }
  }
  probe {
    name                = "portalProbe"
    protocol            = "Https"
    host                = var.portal_hostname
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200"]
    }
  }
  probe {
    name                = "mgmtProbe"
    protocol            = "Https"
    host                = var.management_hostname
    path                = "/ServiceStatus"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200", "404"]
    }
  }
  backend_http_settings {
    name                  = "apiHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    host_name             = var.api_hostname
    pick_host_name_from_backend_address = false
    probe_name            = "apiProbe"
  }
  backend_http_settings {
    name                  = "portalHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    host_name             = var.portal_hostname
    pick_host_name_from_backend_address = false
    probe_name            = "portalProbe"
  }
  backend_http_settings {
    name                  = "mgmtHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    host_name             = var.management_hostname
    pick_host_name_from_backend_address = false
    probe_name            = "mgmtProbe"
  }
  http_listener {
    name                           = "apiListener"
    frontend_ip_configuration_name = "frontendIP"
    frontend_port_name             = "httpsPort"
    protocol                      = "Https"
    host_name                     = var.api_hostname
    ssl_certificate_name          = "wildcardCert"
    require_sni                   = true
  }
  http_listener {
    name                           = "portalListener"
    frontend_ip_configuration_name = "frontendIP"
    frontend_port_name             = "httpsPort"
    protocol                      = "Https"
    host_name                     = var.portal_hostname
    ssl_certificate_name          = "wildcardCert"
    require_sni                   = true
  }
  http_listener {
    name                           = "mgmtListener"
    frontend_ip_configuration_name = "frontendIP"
    frontend_port_name             = "httpsPort"
    protocol                      = "Https"
    host_name                     = var.management_hostname
    ssl_certificate_name          = "wildcardCert"
    require_sni                   = true
  }
  request_routing_rule {
    name                       = "apiRule"
    rule_type                  = "Basic"
    http_listener_name         = "apiListener"
    backend_address_pool_name  = "apimBackend"
    backend_http_settings_name = "apiHttpSettings"
    priority                   = 100
  }
  request_routing_rule {
    name                       = "portalRule"
    rule_type                  = "Basic"
    http_listener_name         = "portalListener"
    backend_address_pool_name  = "apimBackend"
    backend_http_settings_name = "portalHttpSettings"
    priority                   = 200
  }
  request_routing_rule {
    name                       = "mgmtRule"
    rule_type                  = "Basic"
    http_listener_name         = "mgmtListener"
    backend_address_pool_name  = "apimBackend"
    backend_http_settings_name = "mgmtHttpSettings"
    priority                   = 300
  }
  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
    
    # Disable rules that commonly interfere with API Management
    disabled_rule_group {
      rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
      rules = [
        920300,  # Request Missing an Accept Header
        920320   # Missing User Agent Header
      ]
    }
    
    disabled_rule_group {
      rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
      rules = [
        942100,  # SQL Injection Attack Detected via libinjection
        942110,  # SQL Injection Attack: Common Injection Testing Detected
        942130,  # SQL Injection Attack: SQL Tautology Detected
        942180,  # Detects basic SQL authentication bypass attempts 1/3
        942200,  # Detects MySQL comment-/space-obfuscated injections and backtick termination
        942260,  # Detects basic SQL authentication bypass attempts 2/3
        942300,  # Detects MySQL and PostgreSQL stored procedure/function injections
        942370,  # Detects classic SQL injection probings 2/2
        942430,  # Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (8)
        942440   # SQL Comment Sequence Detected
      ]
    }
  }
}

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Your Company"
  publisher_email     = "admin@yourcompany.com"
  sku_name            = "Developer_1"
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }
  identity {
    type = "SystemAssigned"
  }
  hostname_configuration {
    proxy {
      host_name = var.api_hostname
      certificate = filebase64(var.certificate_pfx_path)
      certificate_password = var.certificate_password
    }
    developer_portal {
      host_name = var.portal_hostname
      certificate = filebase64(var.certificate_pfx_path)
      certificate_password = var.certificate_password
    }
    management {
      host_name = var.management_hostname
      certificate = filebase64(var.certificate_pfx_path)
      certificate_password = var.certificate_password
    }
  }
  tags = {
    environment = "landing-zone"
  }
}

resource "azurerm_user_assigned_identity" "appgw" {
  name                = "appgw-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Configure CORS for API Management Developer Portal
resource "azurerm_api_management_api" "cors_api" {
  name                = "cors-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "CORS API"
  path                = ""
  protocols           = ["https"]
  
  depends_on = [azurerm_api_management.apim]
}

resource "azurerm_api_management_api_policy" "cors_policy" {
  api_name            = azurerm_api_management_api.cors_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>https://${var.portal_hostname}</origin>
        <origin>https://${var.management_hostname}</origin>
        <origin>https://${var.api_hostname}</origin>
      </allowed-origins>
      <allowed-methods preflight-result-max-age="300">
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>HEAD</method>
        <method>OPTIONS</method>
        <method>PATCH</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
      <expose-headers>
        <header>*</header>
      </expose-headers>
    </cors>
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Global CORS policy for the entire APIM instance
resource "azurerm_api_management_policy" "global_cors" {
  api_management_id = azurerm_api_management.apim.id

  xml_content = <<XML
<policies>
  <inbound>
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>https://${var.portal_hostname}</origin>
        <origin>https://${var.management_hostname}</origin>
        <origin>https://${var.api_hostname}</origin>
      </allowed-origins>
      <allowed-methods preflight-result-max-age="300">
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>HEAD</method>
        <method>OPTIONS</method>
        <method>PATCH</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
      <expose-headers>
        <header>*</header>
      </expose-headers>
    </cors>
  </inbound>
  <backend />
  <outbound />
  <on-error />
</policies>
XML
}
