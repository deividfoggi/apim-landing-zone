#!/bin/bash

# Get Azure access token
TOKEN=$(az account get-access-token --query accessToken -o tsv)

# Create a temporary file with the policy XML
cat > /tmp/policy.xml << 'EOF'
<policies>
    <inbound>
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>https://portal.thefoggi.com</origin>
                <origin>https://management.thefoggi.com</origin>
                <origin>https://api.thefoggi.com</origin>
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
EOF

# Escape the XML for JSON
ESCAPED_POLICY=$(cat /tmp/policy.xml | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Create JSON payload
cat > /tmp/payload.json << EOF
{
    "properties": {
        "value": "$ESCAPED_POLICY",
        "format": "xml"
    }
}
EOF

# Make the REST API call
curl -X PUT \
  "https://management.azure.com/subscriptions/dc22d6d8-0495-4653-a69b-edfe16840f8e/resourceGroups/apim-lz-rg/providers/Microsoft.ApiManagement/service/apim-thefoggi/policies/policy?api-version=2023-03-01-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/payload.json

# Clean up
rm -f /tmp/policy.xml /tmp/payload.json
