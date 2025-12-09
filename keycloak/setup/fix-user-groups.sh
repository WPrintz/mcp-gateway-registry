#!/bin/bash
# Fix user group assignments and add group mapper to client
set -e

KEYCLOAK_URL="${KEYCLOAK_ADMIN_URL:-https://d18df3db8sg9f7.cloudfront.net}"
REALM="mcp-gateway"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-AdminPassword2025!}"

echo "Fixing Keycloak user groups..."
echo "Keycloak URL: $KEYCLOAK_URL"

# Get admin token
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to authenticate"
    exit 1
fi
echo "Authenticated!"

# Get admin user ID
echo "Finding admin user..."
ADMIN_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=admin" | jq -r '.[0].id')
echo "Admin user ID: $ADMIN_ID"

# Get group IDs and assign user
echo "Assigning groups..."
for group in "mcp-registry-admin" "mcp-servers-unrestricted"; do
    GROUP_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/groups" | jq -r '.[] | select(.name=="'$group'") | .id')
    echo "  Group $group ID: $GROUP_ID"
    if [ ! -z "$GROUP_ID" ] && [ "$GROUP_ID" != "null" ]; then
        curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ADMIN_ID}/groups/${GROUP_ID}" \
            -H "Authorization: Bearer ${TOKEN}"
        echo "  Assigned $group to admin user"
    fi
done

# Add group mapper to client scope
echo "Adding group mapper to client..."
WEB_CLIENT_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=mcp-gateway-web" | jq -r '.[0].id')
echo "Web client ID: $WEB_CLIENT_ID"

# Create a protocol mapper for groups
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${WEB_CLIENT_ID}/protocol-mappers/models" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "groups",
        "protocol": "openid-connect",
        "protocolMapper": "oidc-group-membership-mapper",
        "consentRequired": false,
        "config": {
            "full.path": "false",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "groups",
            "userinfo.token.claim": "true"
        }
    }' 2>/dev/null || echo "  (mapper may already exist)"

echo ""
echo "Done! User should now have groups in their token."
echo "Please log out and log back in to get a new token with groups."
