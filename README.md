# Azure API Management Landing Zone with Application Gateway

This repository contains Terraform infrastructure code to deploy a secure Azure API Management (APIM) landing zone with an Application Gateway as a reverse proxy. The solution follows Azure best practices for internal VNET integration and SSL termination.

## Architecture Overview

The solution deploys:
- **Virtual Network** with dedicated subnets for APIM and Application Gateway
- **API Management** instance in internal VNET mode with CORS configuration
- **Application Gateway** with WAF v2 for SSL termination and routing (Detection mode)
- **Key Vault** for certificate management with RBAC
- **Network Security Groups** with required rules for APIM and App Gateway
- **Custom domain configuration** for API, Portal, and Management endpoints

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.0 installed
- A wildcard SSL certificate in PFX format
- Azure subscription with sufficient permissions

## Current Configuration

This deployment includes several production-ready configurations based on real-world deployment experience:

### 🔧 **WAF Configuration**
- **Mode**: Detection (recommended for APIM integration)
- **Disabled Rules**: Specific WAF rules that commonly interfere with APIM are disabled
- **Monitoring**: Full logging and monitoring while allowing legitimate traffic

### 🔗 **CORS Configuration**
- **Global Policy**: Automatically configured for Developer Portal functionality
- **Allowed Origins**: All custom domain endpoints (api, portal, management)
- **Methods**: All standard HTTP methods (GET, POST, PUT, DELETE, etc.)

### 🔐 **Certificate Management**
- **Key Vault Integration**: Centralized certificate storage with RBAC
- **Wildcard Support**: Single certificate for all endpoints
- **Automatic Renewal Ready**: Infrastructure supports automated certificate updates

### 🌐 **Network Security**
- **Internal VNET**: APIM not directly accessible from internet
- **NSG Rules**: Comprehensive security rules for both APIM and Application Gateway
- **Health Probes**: Proper health check configuration for all endpoints

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
# Navigate to the infrastructure directory
cd infra

# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

**⏱️ Expected Deployment Time**: 30-45 minutes due to APIM provisioning time.

**📋 What Gets Deployed Automatically**:
- ✅ Virtual Network with subnets
- ✅ API Management with internal VNET configuration
- ✅ Application Gateway with WAF in Detection mode
- ✅ Key Vault with certificate upload
- ✅ Network Security Groups with required rules
- ✅ **Global CORS policy for Developer Portal functionality**
- ✅ **WAF rules disabled for APIM compatibility**
- ✅ SSL certificates configured for all endpoints
- ✅ Health probes and backend configurations

## DNS Configuration

After deployment, configure your DNS records to point to the Application Gateway public IP:

### 1. Get the Public IP Address

```bash
# Get the Application Gateway public IP from Terraform output
terraform output application_gateway_public_ip

# Alternative: Get from Azure CLI
az network public-ip show \
  --name apim-yourapimname-appgw-pip \
  --resource-group your-resource-group \
  --query ipAddress \
  --output tsv
```

### 2. Configure DNS Records

Create **A records** (not CNAME) pointing to the Application Gateway IP:

| Record Type | Name | Value |
|-------------|------|-------|
| A | `api.yourdomain.com` | Application Gateway IP |
| A | `portal.yourdomain.com` | Application Gateway IP |
| A | `management.yourdomain.com` | Application Gateway IP |

**⚠️ Important**: Use A records, not CNAME records, for proper SSL certificate validation.

### 3. Verify DNS Propagation

```bash
# Check DNS resolution
nslookup api.yourdomain.com
nslookup portal.yourdomain.com
nslookup management.yourdomain.com

# Or use dig
dig api.yourdomain.com
```

**⏱️ DNS Propagation Time**: 5-60 minutes depending on your DNS provider.

## Verification & Testing

### 1. Verify Deployment Status

```bash
# Check Application Gateway backend health
az network application-gateway show-backend-health \
  --name apim-yourapimname-appgw \
  --resource-group your-resource-group

# Check APIM service status
az apim show \
  --name your-apim-name \
  --resource-group your-resource-group \
  --query provisioningState
```

### 2. Test SSL Certificates

```bash
# Test SSL certificate for each endpoint
curl -I https://api.yourdomain.com
curl -I https://portal.yourdomain.com
curl -I https://management.yourdomain.com
```

**Expected Results**:
- API endpoint: `HTTP/1.1 404` (expected - no APIs configured yet)
- Portal endpoint: `HTTP/1.1 200` 
- Management endpoint: `HTTP/1.1 200`

### 3. Test Developer Portal

**🔧 Critical Steps for Developer Portal**:

1. **Clear Browser Cache**: Essential for CORS to work properly
   ```bash
   # Clear all browser data for your domain
   # Or use incognito/private browsing mode
   ```

2. **Access Developer Portal**: 
   - Navigate to `https://portal.yourdomain.com`
   - You should see the APIM Developer Portal without CORS errors

3. **Check Browser Console**: 
   - Open F12 Developer Tools → Console
   - Should see no CORS-related errors
   - Should see no 503 errors from WAF

### 4. Verify WAF Configuration

```bash
# Check WAF is in Detection mode (not blocking)
az network application-gateway waf-config show \
  --gateway-name apim-yourapimname-appgw \
  --resource-group your-resource-group
```

## Access Your Endpoints

Once DNS is configured and verified, you can access:

- **🌐 API Gateway**: `https://api.yourdomain.com` (for API calls)
- **👨‍💻 Developer Portal**: `https://portal.yourdomain.com` (for developers)
- **⚙️ Management API**: `https://management.yourdomain.com` (for administration)

**🎉 Success Indicators**:
- ✅ All endpoints return valid SSL certificates
- ✅ Developer Portal loads without CORS errors
- ✅ No 503 errors from Application Gateway
- ✅ Backend health checks show "Healthy" status

## 📋 Complete Deployment Checklist

### Pre-Deployment ✅
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Terraform >= 1.0 installed (`terraform --version`)
- [ ] Wildcard SSL certificate in PFX format available
- [ ] Certificate password known
- [ ] Unique names chosen for APIM and Key Vault

### Deployment ✅
- [ ] Repository cloned
- [ ] Certificate placed in `certificate/` directory
- [ ] `terraform.tfvars` configured with your values
- [ ] Certificate path updated in `variables.tf` (if needed)
- [ ] `terraform init` completed successfully
- [ ] `terraform plan` reviewed
- [ ] `terraform apply` completed (30-45 mins)

### Post-Deployment ✅
- [ ] Application Gateway public IP obtained
- [ ] DNS A records created and propagated
- [ ] SSL certificates verified for all endpoints
- [ ] Backend health checks show "Healthy"
- [ ] Developer Portal accessible without CORS errors
- [ ] Browser cache cleared for testing

### Troubleshooting (if needed) ✅
- [ ] WAF logs checked if seeing 503 errors
- [ ] DNS propagation verified
- [ ] Certificate password and format verified
- [ ] RBAC permissions confirmed in Azure portal

## 🚨 Quick Troubleshooting

**Developer Portal shows CORS errors?**
```bash
# 1. Clear browser cache completely
# 2. Try incognito/private mode
# 3. Check if CORS policy deployed:
az apim policy list --resource-group your-rg --service-name your-apim
```

**Getting 503 errors?**
```bash
# Check Application Gateway WAF logs
az monitor activity-log list --resource-group your-rg --max-events 50
```

**SSL certificate issues?**
```bash
# Verify certificate in Key Vault
az keyvault certificate show --vault-name your-kv --name wildcard-yourdomain-com
```

**DNS not resolving?**
```bash
# Check DNS propagation
nslookup api.yourdomain.com 8.8.8.8
```

## Security Features

- **Internal VNET**: APIM is deployed in internal mode, not directly accessible from internet
- **WAF Protection**: Application Gateway provides Web Application Firewall protection in Detection mode
- **SSL Termination**: HTTPS termination at Application Gateway with certificate from Key Vault
- **RBAC**: Key Vault uses RBAC for modern access control
- **NSG Rules**: Proper network security group rules for APIM and Application Gateway
- **CORS Policy**: Global CORS configuration enables Developer Portal functionality

### WAF Configuration

The Application Gateway WAF is configured in **Detection mode** with specific rules disabled to ensure APIM functionality:

- **Mode**: Detection (monitors but doesn't block)
- **Disabled Rule Groups**:
  - `REQUEST-920-PROTOCOL-ENFORCEMENT` (rules 920300, 920320)
  - `REQUEST-942-APPLICATION-ATTACK-SQLI` (multiple SQL injection detection rules)

This configuration allows legitimate APIM management traffic while still providing security monitoring.

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

4. **Developer Portal CORS Issues** ⚠️ **Common Issue**
   - **Symptoms**: Portal shows errors when trying to access APIs, browser console shows CORS policy errors
   - **Cause**: Missing CORS configuration for Developer Portal communication with Management API
   - **Solution**: Global CORS policy is automatically configured in the Terraform deployment
   - **Manual Fix**: If issues persist, clear browser cache and test in incognito mode

5. **WAF Blocking APIM Traffic** ⚠️ **Common Issue**
   - **Symptoms**: HTTP 503 errors on management endpoint, API calls failing
   - **Cause**: WAF rules blocking legitimate APIM management requests
   - **Solution**: WAF is configured in Detection mode with problematic rules disabled
   - **Manual Fix**: Check Application Gateway WAF logs for blocked requests

### Post-Deployment Verification

After deployment, verify the following:

1. **Clear Browser Cache**: Clear all browser cache and cookies for your custom domain
2. **Test Developer Portal**: Open `https://portal.yourdomain.com` in incognito mode
3. **Check Backend Health**: Verify all Application Gateway backend pools are healthy
4. **Test API Endpoints**: Ensure APIs are accessible through `https://api.yourdomain.com`

### Debugging Commands

```bash
# Check Application Gateway backend health
az network application-gateway show-backend-health \
  --name apim-yourapimname-appgw \
  --resource-group your-resource-group

# Check APIM service status
az apim show \
  --name your-apim-name \
  --resource-group your-resource-group \
  --query provisioningState

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

- **API Management**: Developer SKU is cost-effective for testing (~$50/month), Premium for production (~$3000/month)
- **Application Gateway**: WAF v2 has hourly charges (~$250/month) plus capacity unit charges
- **Key Vault**: Minimal cost for certificate storage (~$3/month)
- **Storage/Networking**: Additional costs for virtual network and storage resources

💡 **Cost Optimization Tips**:
- Use Developer SKU for non-production environments
- Configure Application Gateway auto-scaling to optimize capacity costs
- Monitor WAF logs to ensure Detection mode is appropriate before switching to Prevention

## Known Limitations & Recommendations

### 🚨 **Current Limitations**
- **WAF in Detection Mode**: For optimal APIM compatibility, WAF is in Detection mode rather than Prevention
- **Wildcard CORS**: CORS headers are configured with wildcards for maximum compatibility

### 📋 **Production Recommendations**

#### Security Hardening
1. **WAF Monitoring**: Monitor WAF logs for 30 days in Detection mode
2. **Gradual Rule Re-enablement**: Selectively re-enable WAF rules after confirming no false positives
3. **CORS Refinement**: Restrict CORS origins to specific required domains after testing

#### Operational Excellence
1. **Certificate Automation**: Implement automated certificate renewal
2. **Monitoring**: Deploy Application Insights for comprehensive monitoring
3. **Backup Strategy**: Implement APIM configuration backup procedures

#### Performance Optimization
1. **Premium SKU**: Use Premium SKU for production workloads
2. **Multi-Region**: Consider multi-region deployment for global applications
3. **Caching**: Implement appropriate caching strategies

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
