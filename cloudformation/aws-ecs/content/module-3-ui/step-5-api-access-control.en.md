---
title: "3.5 Access Control via API (Optional)"
weight: 45
---

Everything you did in Steps 3.3 and 3.4 through the IAM Settings panel can also be done through the Registry API. This section walks through the same operations using `curl` commands in AWS CloudShell — useful for automation pipelines, infrastructure-as-code workflows, and understanding how the UI communicates with the backend.

::alert[This section is optional. If you completed Steps 3.3 and 3.4 through the UI, you already have a working access control configuration. This section demonstrates the **same operations** via API for participants who want to understand the programmatic interface.]{type="info"}

---

## Prerequisites

You'll need AWS CloudShell for this section. See [Step 1.1](/module-1/step-1-cloudformation-outputs) if you need help opening it from the AWS Console.

### Set Environment Variables

:::code{language=bash showCopyAction=true}
export KEYCLOAK_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`KeycloakUrl`].OutputValue' --output text)
export GATEWAY_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`MCPGatewayUrl`].OutputValue' --output text)
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Gateway URL: $GATEWAY_URL"
:::

### Get an Admin Token

:::code{language=bash showCopyAction=true}
curl -o get-m2m-token.sh https://raw.githubusercontent.com/agentic-community/mcp-gateway-registry/main/api/get-m2m-token.sh
chmod +x get-m2m-token.sh
./get-m2m-token.sh --aws-region $AWS_REGION --keycloak-url $KEYCLOAK_URL --output-file /tmp/admin-token registry-admin-bot
:::

::alert[**Token expiry:** M2M tokens have a 300-second TTL. If you get a 401, 500, or "jq: parse error: Invalid numeric..."  error later in this section, re-run the `get-m2m-token.sh` command to get a fresh token.]{type="warning"}

---

## Part A: View and Test Access Control (API Equivalent of 3.3)

In Step 3.3, you modified LOB1's group membership and scope definition through the IAM Settings panel. Here you'll see how to view and modify the same data through the API.

### Step 1: View All Scopes

List all scope definitions stored in DocumentDB:

:::code{language=bash showCopyAction=true}
curl -s -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/servers/groups | jq .
:::

The response contains five sections:

| Section | What It Shows |
|---------|---------------|
| `scopes_groups` | All scope definitions from DocumentDB, keyed by scope name |
| `keycloak_groups` | All groups that exist in Keycloak (or your IdP) |
| `synchronized` | Groups that exist in **both** Keycloak and DocumentDB |
| `keycloak_only` | Groups that exist in Keycloak but have no scope definition in DocumentDB |
| `scopes_only` | Scopes defined in DocumentDB with no matching Keycloak group |

### Step 2: View LOB1's Scope Detail

Get the full scope definition for `registry-users-lob1`:

:::code{language=bash showCopyAction=true}
curl -s -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/servers/groups/registry-users-lob1 | jq .
:::

If you completed Step 3.3, you should see `cloudflare-docs` in both the `server_access` array and in `ui_permissions.list_service`. This is the scope document that the UI's JSON Preview showed you — now you're seeing it directly from DocumentDB.

### Step 3: Test MCP Tool-Level Enforcement

This is where the API really shines — you can verify the three-layer enforcement model directly. Get a LOB1 M2M token:

:::code{language=bash showCopyAction=true}
./get-m2m-token.sh --aws-region $AWS_REGION --keycloak-url $KEYCLOAK_URL --output-file /tmp/lob1-token lob1-bot
:::

**Test the allowed tool** (`search_cloudflare_documentation`):

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "search_cloudflare_documentation",
      "arguments": {
        "query": "how to configure Workers"
      }
    }
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see actual Cloudflare documentation content. Now **test the denied tool** (`migrate_pages_to_workers_guide`):

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "migrate_pages_to_workers_guide",
      "arguments": {}
    }
  }'
:::

This returns **403 Forbidden** — LOB1's scope only allows `search_cloudflare_documentation`. The Auth Server blocks the request before it reaches the upstream Cloudflare server.

::alert[This is the same enforcement you verified through the UI in Step 3.3. The MCP Gateway checks the `tools` array in the scope's `server_access` entry for `cloudflare-docs`. LOB1 can **list** both tools via `tools/list`, but can only **invoke** the one in their scope.]{type="info"}

### Step 4: Update a Scope via API

To modify a scope programmatically, use the **import** endpoint. This creates or updates a scope definition in DocumentDB. Here's the JSON structure for LOB1's scope — the same document you saw in the JSON Preview panel:

:::code{language=bash showCopyAction=true}
cat > /tmp/lob1-scope-update.json << 'EOF'
{
  "scope_name": "registry-users-lob1",
  "description": "LOB1 scope - managed via API",
  "group_mappings": ["registry-users-lob1"],
  "server_access": [
    {
      "server": "currenttime",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call"],
      "tools": ["current_time_by_timezone"]
    },
    {
      "server": "airegistry-tools",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call"],
      "tools": ["intelligent_tool_finder"]
    },
    {
      "server": "cloudflare-docs",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call"],
      "tools": ["search_cloudflare_documentation"]
    }
  ],
  "ui_permissions": {
    "list_service": ["currenttime", "airegistry-tools", "cloudflare-docs"],
    "health_check_service": ["currenttime", "airegistry-tools", "cloudflare-docs"],
    "get_service": ["currenttime", "airegistry-tools", "cloudflare-docs"],
    "list_tools": ["currenttime", "airegistry-tools", "cloudflare-docs"],
    "call_tool": ["currenttime", "airegistry-tools", "cloudflare-docs"]
  },
  "create_in_idp": false
}
EOF
:::

Import the scope:

:::code{language=bash showCopyAction=true}
curl -s -X POST \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -d @/tmp/lob1-scope-update.json \
  $GATEWAY_URL/api/servers/groups/import | jq .
:::

You should see:

```json
{
  "message": "Group registry-users-lob1 imported successfully",
  "group_name": "registry-users-lob1",
  "idp_created": false,
  "auth_server_reloaded": true
}
```

The scope changes are in DocumentDB immediately. The Auth Server queries DocumentDB on every request, so changes take effect without any restart or redeployment.

::alert[The `create_in_idp: false` flag tells the API to only update DocumentDB — the Keycloak group already exists. Set it to `true` when creating a brand-new group that should also be created in the identity provider.]{type="info"}

### Understanding the Scope Document

Each field in the scope document controls a specific layer of enforcement:

| Field | Layer | What It Controls |
|-------|-------|-----------------|
| `group_mappings` | Identity | Which Keycloak groups activate this scope |
| `ui_permissions.list_service` | Layer 1 — UI Visibility | Which server cards appear in the dashboard |
| `server_access[].methods` | Layer 2 — Method Access | Which MCP protocol operations are allowed |
| `server_access[].tools` | Layer 3 — Tool Permissions | Which specific tools can be invoked |

This is the same three-layer model you saw in the Groups editor's JSON Preview — the API gives you direct access to the underlying document.

---

## Part B: Create Resources via API (API Equivalent of 3.4)

In Step 3.4, you created a `data-engineering` group, a `data-eng-user`, and a `data-eng-bot` M2M account through the IAM Settings panel. Here you'll do the same thing entirely via API.

::alert[**Token expiry Reminder:** M2M tokens have a 300-second TTL. If you get a 401, 500, or "jq: parse error: Invalid numeric..."  error later in this section, re-run the `get-m2m-token.sh` command to get a fresh token.]{type="warning"}

### Step 5: Create the Group and Scope

The import endpoint can create a new group in both DocumentDB and Keycloak in a single call when `create_in_idp` is set to `true`:

:::code{language=bash showCopyAction=true}
cat > /tmp/data-eng-scope.json << 'EOF'
{
  "scope_name": "data-engineering",
  "description": "Data Engineering team - Cloudflare Documentation access",
  "group_mappings": ["data-engineering"],
  "server_access": [
    {
      "server": "cloudflare-docs",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call"],
      "tools": ["*"]
    }
  ],
  "ui_permissions": {
    "list_service": ["cloudflare-docs"],
    "health_check_service": ["cloudflare-docs"],
    "get_service": ["cloudflare-docs"],
    "list_tools": ["cloudflare-docs"],
    "call_tool": ["cloudflare-docs"]
  },
  "create_in_idp": true
}
EOF
:::

:::code{language=bash showCopyAction=true}
curl -s -X POST \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -d @/tmp/data-eng-scope.json \
  $GATEWAY_URL/api/servers/groups/import | jq .
:::

You should see `"idp_created": true` in the response — the group now exists in both Keycloak and DocumentDB.

Compare this to Step 3.4 Step 1 where you filled in the group form, added the server access entry, and clicked Create Group. The API does the same thing in a single POST request.

### Step 6: Create a Human User

If you completed Step 3.4, the `data-eng-user` already exists. Here you'll create a second user in the same group to see the API in action:

:::code{language=bash showCopyAction=true}
curl -s -X POST \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "data-eng-user2",
    "email": "data-eng2@example.com",
    "firstname": "Data",
    "lastname": "Analyst",
    "password": "datapass2",
    "groups": ["data-engineering"]
  }' \
  $GATEWAY_URL/api/management/iam/users/human | jq .
:::

The response confirms the user was created in Keycloak and assigned to the `data-engineering` group — the same operation as Step 3.4 Step 2, just via API instead of the UI form.

### Step 7: Create an M2M Service Account

:::code{language=bash showCopyAction=true}
curl -s -X POST \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "data-eng-bot2",
    "description": "Data Engineering automation pipeline (API-created)",
    "groups": ["data-engineering"]
  }' \
  $GATEWAY_URL/api/management/iam/users/m2m | jq .
:::

The response includes a `client_id` and `client_secret`. **Save these values** — the secret is displayed only once, just like in the UI.
The `client_uuid` is not used in this section.

:::code{language=bash showCopyAction=true}
# Save the credentials from the response above
export DATA_ENG_CLIENT_ID="<paste client_id here>"
export DATA_ENG_CLIENT_SECRET="<paste client_secret here>"
:::

### Step 8: Get a Token and Test Access

Now use the OAuth2 Client Credentials flow directly — this is what happens behind the scenes when `get-m2m-token.sh` runs. You should see no response after running this command.

:::code{language=bash showCopyAction=true}
curl -s -X POST "$KEYCLOAK_URL/realms/mcp-gateway/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$DATA_ENG_CLIENT_ID" \
  -d "client_secret=$DATA_ENG_CLIENT_SECRET" | jq -r '.access_token' > /tmp/data-eng-token
:::

Test MCP access with the new token:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/data-eng-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see both Cloudflare Documentation tools — `search_cloudflare_documentation` and `migrate_pages_to_workers_guide`. Unlike LOB1 (which can only invoke the search tool), the data-engineering scope has `tools: ["*"]`, so both tools are allowed.

Verify by calling the migration guide tool:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/data-eng-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "migrate_pages_to_workers_guide",
      "arguments": {}
    }
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

This succeeds — confirming that the wildcard `"*"` in the tools array grants access to all tools on the server.

### Step 9: Clean Up

Delete the resources in reverse order, just as you did in Step 3.4 Step 5.

::alert[**Token expiry Reminder:** M2M tokens have a 300-second TTL. If you get a 401, 500, or "jq: parse error: Invalid numeric..."  error later in this section, re-run the `get-m2m-token.sh` command to get a fresh token.]{type="warning"}

**Delete the M2M account:**

:::code{language=bash showCopyAction=true}
curl -s -X DELETE \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/management/iam/users/data-eng-bot2 | jq .
:::

**Delete the user:**

:::code{language=bash showCopyAction=true}
curl -s -X DELETE \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/management/iam/users/data-eng-user2 | jq .
:::

**Delete the group and scope:**

:::code{language=bash showCopyAction=true}
curl -s -X DELETE \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/management/iam/groups/data-engineering | jq .
:::

The group is removed from both Keycloak and DocumentDB. Any tokens issued for `data-eng-bot2` become useless — the scope no longer exists in DocumentDB, so the Auth Server will deny all requests.

---

## API Reference Summary

Here's a quick reference for the IAM management endpoints used in this section:

### Scope/Group Management (`/api/servers/groups`)

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List all scopes | `GET` | `/api/servers/groups` |
| Get scope detail | `GET` | `/api/servers/groups/{group_name}` |
| Create or update scope | `POST` | `/api/servers/groups/import` |
| Delete group and scope | `POST` | `/api/servers/groups/delete` |

### User and M2M Management (`/api/management/iam`)

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List users | `GET` | `/api/management/iam/users` |
| Create human user | `POST` | `/api/management/iam/users/human` |
| Create M2M account | `POST` | `/api/management/iam/users/m2m` |
| Update user groups | `PATCH` | `/api/management/iam/users/{username}/groups` |
| Delete user or M2M | `DELETE` | `/api/management/iam/users/{username}` |
| List groups | `GET` | `/api/management/iam/groups` |
| Delete group | `DELETE` | `/api/management/iam/groups/{group_name}` |

All endpoints require an admin Bearer token (`registry-admin-bot`).

---

## UI vs API: When to Use Each

| Use Case | UI (IAM Settings) | API |
|----------|--------------------|-----|
| **Ad-hoc changes** | Best — visual feedback, JSON Preview | Overkill |
| **Automation pipelines** | Not practical | Best — scriptable, version-controllable |
| **Infrastructure-as-code** | Not applicable | Best — scope JSON can be stored in Git |
| **Bulk operations** | Tedious | Best — loop over API calls |
| **Debugging permissions** | Good — JSON Preview | Good — direct DocumentDB view |
| **Onboarding new teams** | Quick for 1-2 teams | Better for many teams |

::alert[In production, many teams use the API to manage scope definitions as code — storing scope JSON files in a Git repository and applying them via CI/CD pipelines. The UI remains useful for ad-hoc changes and debugging.]{type="info"}
