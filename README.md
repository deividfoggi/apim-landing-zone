# Azure API Management Landing Zone with Application Gateway

This repository contains Terraform infrastructure code to deploy a secure Azure API Management (APIM) landing zone with an Application Gateway as a reverse proxy. The solution follows Azure best practices for internal VNET integration and SSL termination.

## Architecture Overview

The solution deploys:
- **Virtual Network** with dedicated subnets for APIM and Application Gateway
- **API Management** instance in internal VNET mode
- **Application Gateway** with WAF v2 for SSL termination and routing
- **Key Vault** for certificate management with RBAC
- **Network Security Groups** with required rules for APIM and App Gateway
- **Custom domain configuration** for API, Portal, and Management endpoints

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.0 installed
- A wildcard SSL certificate in PFX format
- Azure subscription with sufficient permissions

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/apim-landing-zone.git
cd apim-landing-zone
```

### 2. Prepare Your Certificate

Place your wildcard SSL certificate (PFX format) in the `certificate/` directory:

```bash
# Create certificate directory if it doesn't exist
mkdir -p certificate

# Copy your certificate file
cp /path/to/your/wildcard.yourdomain.com.pfx certificate/
```

**Certificate Requirements:**
- Must be a wildcard certificate (e.g., `*.yourdomain.com`)
- Must be in PFX format
- Must include the private key

### 3. Configure Variables

Navigate to the `infra/` directory and update the `terraform.tfvars` file:

```bash
cd infra
```

Edit `terraform.tfvars` with your specific values:

```terraform
# Azure region to deploy resources
location            = "eastus2"

# Resource group name
resource_group_name = "apim-lz-rg"

# API Management instance name (must be globally unique)
apim_name           = "your-unique-apim-name"

# Custom domain configuration
custom_domain       = "yourdomain.com"
api_hostname        = "api.yourdomain.com"
portal_hostname     = "portal.yourdomain.com"
management_hostname = "management.yourdomain.com"

# Certificate configuration
certificate_password = "your-certificate-password"

# Key Vault name (must be globally unique)
key_vault_name      = "your-unique-kv-name"
```

**Important Notes:**
- `apim_name` must be globally unique across all Azure subscriptions
- `key_vault_name` must be globally unique across all Azure subscriptions
- Update the certificate path in `variables.tf` if you named your certificate file differently

### 4. Update Certificate Path (if needed)

If your certificate file has a different name, update the default path in `variables.tf`:

```terraform
variable "certificate_pfx_path" {
  description = "Path to the wildcard PFX certificate file"
  type        = string
  default     = "../certificate/your-certificate-filename.pfx"  # Update this line
}
```

### 5. Deploy the Infrastructure

Initialize and apply Terraform:

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

The deployment typically takes 30-45 minutes due to APIM provisioning time.

## DNS Configuration

After deployment, configure your DNS records to point to the Application Gateway public IP:

1. Get the Application Gateway public IP from the output:
   ```bash
   terraform output application_gateway_public_ip
   ```

2. Create DNS A records:
   - `api.yourdomain.com` → Application Gateway IP
   - `portal.yourdomain.com` → Application Gateway IP
   - `management.yourdomain.com` → Application Gateway IP

## Access Your Endpoints

Once DNS is configured, you can access:

- **API Gateway**: `https://api.yourdomain.com`
- **Developer Portal**: `https://portal.yourdomain.com`
- **Management API**: `https://management.yourdomain.com`

## Security Features

- **Internal VNET**: APIM is deployed in internal mode, not directly accessible from internet
- **WAF Protection**: Application Gateway provides Web Application Firewall protection
- **SSL Termination**: HTTPS termination at Application Gateway with certificate from Key Vault
- **RBAC**: Key Vault uses RBAC for modern access control
- **NSG Rules**: Proper network security group rules for APIM and Application Gateway

## Customization

### Changing APIM SKU

The default deployment uses `Developer_1` SKU. For production, update in `apim_landing_zone.tf`:

```terraform
resource "azurerm_api_management" "apim" {
  # ... other configuration ...
  sku_name = "Premium_1"  # Change this for production
}
```

### Scaling Application Gateway

To scale the Application Gateway, update the capacity in `apim_landing_zone.tf`:

```terraform
resource "azurerm_application_gateway" "appgw" {
  # ... other configuration ...
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 5  # Increase this value
  }
}
```

## Troubleshooting

### Common Issues

1. **Certificate Import Fails**
   - Verify certificate password is correct
   - Ensure certificate is in PFX format with private key
   - Check certificate file path

2. **Key Vault Access Denied**
   - Ensure you have sufficient permissions on the Azure subscription
   - RBAC role assignments may take time to propagate

3. **APIM Deployment Timeout**
   - APIM deployment can take 30-45 minutes
   - If it times out, check Azure portal for actual status

### Debugging Commands

```bash
# Check Terraform state
terraform show

# Validate configuration
terraform validate

# Check outputs
terraform output

# Destroy environment (when needed)
terraform destroy
```

## Cost Considerations

- **API Management**: Developer SKU is cost-effective for testing, but consider Premium for production
- **Application Gateway**: WAF v2 has hourly and capacity unit charges
- **Key Vault**: Minimal cost for certificate storage

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Azure documentation for [APIM VNET integration](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway)
3. Open an issue in this repository
