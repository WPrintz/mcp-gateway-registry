#!/bin/bash
# Initialize Keycloak with MCP Gateway configuration - Remote version
# This script is for initializing Keycloak on a remote CloudFront/ECS deployment

set -e

# Remote Keycloak configuration - EDIT THESE VALUES
KEYCLOAK_URL="${KEYCLOAK_ADMIN_URL:-https://d18df3db8sg9f7.cloudfront.net}"
REALM="mcp-gateway"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-AdminPassword2025!}"
AUTH_SERVER_EXTERNAL_URL="${AUTH_SERVER_EXTERNAL_URL:-https://d2iifkocto1yn6.cloudfront.net}"
REGISTRY_URL="${REGISTRY_URL:-https://d2iifkocto1yn6.cloudfront.net}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Keycloak Remote Initialization for MCP Gateway${NC}"
echo "=============================================="
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Registry URL: $REGISTRY_URL"
echo ""

# Get admin token
echo "Authenticating with Keycloak..."
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}Failed to authenticate with Keycloak${NC}"
    exit 1
fi
echo -e "${GREEN}Authentication successful!${NC}"

# Check if realm exists
echo "Checking if realm exists..."
REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}")

if [ "$REALM_STATUS" = "200" ]; then
    echo -e "${YELLOW}Realm already exists. Skipping creation...${NC}"
else
    echo "Creating realm..."
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "mcp-gateway",
            "enabled": true,
            "registrationAllowed": false,
            "loginWithEmailAllowed": true,
            "duplicateEmailsAllowed": false,
            "resetPasswordAllowed": true
        }'
    echo -e "${GREEN}Realm created!${NC}"
fi

# Create web client
echo "Creating mcp-gateway-web client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "clientId": "mcp-gateway-web",
        "name": "MCP Gateway Web Client",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "redirectUris": [
            "'${AUTH_SERVER_EXTERNAL_URL}'/oauth2/callback/keycloak",
            "'${REGISTRY_URL}'/*",
            "http://localhost:7860/*",
            "http://localhost:8888/*"
        ],
        "webOrigins": ["'${REGISTRY_URL}'", "http://localhost:7860", "+"],
        "protocol": "openid-connect",
        "standardFlowEnabled": true,
        "directAccessGrantsEnabled": true,
        "publicClient": false
    }' > /dev/null 2>&1
echo -e "${GREEN}Web client created!${NC}"

# Create groups
echo "Creating groups..."
for group in "mcp-registry-admin" "mcp-registry-user" "mcp-servers-unrestricted"; do
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/groups" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"name": "'$group'"}' > /dev/null 2>&1
done
echo -e "${GREEN}Groups created!${NC}"

# Create admin user
echo "Creating admin user..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "admin",
        "email": "admin@example.com",
        "enabled": true,
        "emailVerified": true,
        "firstName": "Admin",
        "lastName": "User",
        "credentials": [{"type": "password", "value": "changeme", "temporary": false}]
    }' > /dev/null 2>&1

# Get admin user ID and assign to groups
ADMIN_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=admin" | jq -r '.[0].id')

if [ ! -z "$ADMIN_ID" ] && [ "$ADMIN_ID" != "null" ]; then
    for group in "mcp-registry-admin" "mcp-servers-unrestricted"; do
        GROUP_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
            "${KEYCLOAK_URL}/admin/realms/${REALM}/groups" | jq -r '.[] | select(.name=="'$group'") | .id')
        if [ ! -z "$GROUP_ID" ]; then
            curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ADMIN_ID}/groups/${GROUP_ID}" \
                -H "Authorization: Bearer ${TOKEN}" > /dev/null 2>&1
        fi
    done
fi
echo -e "${GREEN}Admin user created!${NC}"

# Generate client secret
echo "Generating client secret..."
WEB_CLIENT_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=mcp-gateway-web" | jq -r '.[0].id')

curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${WEB_CLIENT_ID}/client-secret" \
    -H "Authorization: Bearer ${TOKEN}" > /dev/null 2>&1

CLIENT_SECRET=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${WEB_CLIENT_ID}/client-secret" | jq -r '.value')

echo ""
echo -e "${GREEN}=============================================="
echo "Keycloak initialization complete!"
echo "==============================================${NC}"
echo ""
echo "Realm: ${REALM}"
echo "Client ID: mcp-gateway-web"
echo "Client Secret: ${CLIENT_SECRET}"
echo ""
echo "Test user: admin / changeme"
echo ""
echo -e "${YELLOW}IMPORTANT: Update the client secret in AWS Secrets Manager:${NC}"
echo "aws secretsmanager update-secret --secret-id mcp-gateway-keycloak-client-secret --secret-string '{\"client_secret\":\"${CLIENT_SECRET}\"}' --region us-west-2"
