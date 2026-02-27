---
title: "3.3 Modify Access Control"
weight: 43
---

You've seen the effect of access control — now you'll change it. There are two control planes: **Keycloak** controls *who gets which scope*, and **DocumentDB** controls *what each scope allows*. You'll modify both.

::alert[**Prerequisite:** All four MCP servers must be **enabled** and showing **healthy** status before proceeding. If any server shows disabled or unhealthy, log in as `admin`, navigate to the dashboard, enable each server using the toggle, and refresh the health status. MCP protocol commands in this lab will return "405 Method Not Allowed" if the servers are not enabled and healthy.]{type="warning"}

## Part A: Change Group Membership in Keycloak

First, you'll change *which scope applies* to a user by modifying their Keycloak group membership.

### Step 1: Get Keycloak Admin Credentials

::alert[**Tip:** You can run these commands in AWS CloudShell, accessible from the terminal icon in the bottom toolbar of the AWS Console. CloudShell provides a browser-based shell with the AWS CLI pre-installed and authenticated with your current session.]{type="info"}

:::code{language=bash showCopyAction=true}
aws ssm get-parameter --name /keycloak/admin --with-decryption --query 'Parameter.Value' --output text --region us-west-2
:::

:::code{language=bash showCopyAction=true}
aws ssm get-parameter --name /keycloak/admin_password --with-decryption --query 'Parameter.Value' --output text --region us-west-2
:::

### Step 2: Add lob1-user to a Second Group

1. Open the Keycloak URL in a new browser tab (from your CloudFormation outputs)
2. Click **Administration Console** and login with the credentials above
3. Switch from the **master** realm to **mcp-gateway** realm using the dropdown in the top-left corner
4. Navigate to **Users** → search for `lob1-user` → click to open
5. Click the **Groups** tab — you should see one group: `registry-users-lob1`
6. Click **Join Group** → navigate to page 2 if needed to find `registry-users-lob2` → select it → click **Join**

:image[lob1-user group membership before change]{src="/static/img/module-3/3_3/keycloak_lob1_group_before.png" width=800}

:image[Adding lob1-user to registry-users-lob2]{src="/static/img/module-3/3_3/keycloak_lob1_group_after.png" width=800}

### Step 3: Verify the Change

1. Switch to the MCP Gateway Registry tab
2. **Logout** and **login again** as `lob1-user` / `lob1pass` (the new group takes effect on next login)

You should now see **3 servers** — up from 2:

| Server | Before | After |
|--------|--------|-------|
| Current Time API | ✅ | ✅ |
| MCP Gateway Tools | ✅ | ✅ |
| Real Server Fake Tools | ❌ | ✅ |
| Cloudflare Documentation | ❌ | ❌ |

:image[lob1-user now sees 3 servers]{src="/static/img/module-3/3_3/registry_lob1_3_mcp.png" width=800}

Notice that Cloudflare Documentation is still invisible — LOB 2's scope doesn't include it either. To grant access to the Cloudflare server, you need to modify the scope document itself.

::alert[No code was changed. No services were redeployed. A group membership change in Keycloak caused the authorization pipeline — JWT groups claim → DocumentDB scope lookup → UI filtering — to return a different result.]{type="info"}

---

## Part B: Modify Scope Permissions via API

Now you'll change *what a scope allows* by updating the scope document in DocumentDB through the Registry API. You'll grant LOB 1 access to the Cloudflare Documentation server you registered in Lab 2 — but with a twist: only the `search_cloudflare_documentation` tool, not `migrate_pages_to_workers_guide`.

### Step 4: Get an Admin API Token

First, retrieve the Keycloak URL and Gateway URL from CloudFormation outputs and set them as environment variables:

:::code{language=bash showCopyAction=true}
export KEYCLOAK_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region us-west-2 --query 'Stacks[0].Outputs[?OutputKey==`KeycloakUrl`].OutputValue' --output text)
export GATEWAY_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region us-west-2 --query 'Stacks[0].Outputs[?OutputKey==`MCPGatewayUrl`].OutputValue' --output text)
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Gateway URL: $GATEWAY_URL"
:::

Now download the `get-m2m-token.sh` script from the upstream repository and run it:

:::code{language=bash showCopyAction=true}
# Download the script
curl -o get-m2m-token.sh https://raw.githubusercontent.com/agentic-community/mcp-gateway-registry/main/api/get-m2m-token.sh
chmod +x get-m2m-token.sh

# Get admin token
./get-m2m-token.sh --aws-region us-west-2 --keycloak-url $KEYCLOAK_URL --output-file /tmp/admin-token registry-admin-bot
:::

### Step 5: View Current Scopes

List all scope definitions to see what LOB1 currently has access to:

:::code{language=bash showCopyAction=true}
curl -s -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  $GATEWAY_URL/api/servers/groups | jq .
:::

In the response, find `registry-users-lob1` inside the `scopes_groups` object. Note the `server_count` (currently 3 — api, currenttime, mcpgw) and the `ui_scopes` showing which servers appear in the dashboard. The group should also appear in the `synchronized` array, confirming it exists in both Keycloak and DocumentDB.

### Step 6: Test Tool Access Before Scope Change

Before modifying the scope, let's verify that LOB1 users cannot access the Cloudflare Documentation server. First, get a token for the lob1-user:

:::code{language=bash showCopyAction=true}
# Get LOB1 user token
./get-m2m-token.sh --aws-region us-west-2 --keycloak-url $KEYCLOAK_URL --output-file /tmp/lob1-token lob1-bot
:::

Now try to initialize an MCP session with the Cloudflare Documentation server:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }'
:::

You should see an error response indicating access is denied because `cloudflare-docs` is not in LOB1's scope.

### Step 7: Add Cloudflare Documentation to LOB1's Scope

Create a file with an updated scope definition that adds `cloudflare-docs` with one specific tool:

:::code{language=bash showCopyAction=true}
cat > /tmp/lob1-scope-update.json << 'EOF'
{
  "scope_name": "registry-users-lob1",
  "description": "LOB1 scope - updated with Cloudflare Documentation access",
  "group_mappings": ["registry-users-lob1"],
  "server_access": [
    {
      "server": "api",
      "methods": ["initialize", "GET"],
      "tools": ["servers", "agents"]
    },
    {
      "server": "currenttime",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call", "resources/list", "resources/templates/list"],
      "tools": ["current_time_by_timezone"]
    },
    {
      "server": "mcpgw",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call", "resources/list", "resources/templates/list"],
      "tools": ["intelligent_tool_finder"]
    },
    {
      "server": "cloudflare-docs",
      "methods": ["initialize", "notifications/initialized", "ping", "tools/list", "tools/call"],
      "tools": ["search_cloudflare_documentation"]
    }
  ],
  "ui_permissions": {
    "list_service": ["currenttime", "mcpgw", "cloudflare-docs"],
    "health_check_service": ["currenttime", "mcpgw", "cloudflare-docs"],
    "get_service": ["currenttime", "mcpgw", "cloudflare-docs"],
    "list_tools": ["currenttime", "mcpgw", "cloudflare-docs"],
    "call_tool": ["currenttime", "mcpgw", "cloudflare-docs"]
  },
  "create_in_idp": false
}
EOF
:::

Look at what changed compared to the original LOB1 scope:

| Field | Original | Updated |
|-------|----------|---------|
| `ui_permissions.list_service` | `[currenttime, mcpgw]` | `[currenttime, mcpgw, cloudflare-docs]` |
| `server_access` | 3 entries (api, currenttime, mcpgw) | 4 entries (added `cloudflare-docs`) |
| `cloudflare-docs.tools` | *(not present)* | `[search_cloudflare_documentation]` |

::alert[Notice the `tools` array on `cloudflare-docs` only includes 1 of the 2 tools on that server. LOB1 users will be able to **see** both tools via `tools/list`, but can only **invoke** `search_cloudflare_documentation`. Calling `migrate_pages_to_workers_guide` will return 403 Forbidden.]{type="info"}

### Step 8: Import the Updated Scope

:::code{language=bash showCopyAction=true}
curl -s -X POST \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -d @/tmp/lob1-scope-update.json \
  $GATEWAY_URL/api/servers/groups/import | jq .
:::

You should see a success response:

```json
{
  "message": "Group registry-users-lob1 imported successfully",
  "group_name": "registry-users-lob1",
  "idp_created": false,
  "auth_server_reloaded": false
}
```

The scope changes are now in DocumentDB. The Auth Server queries DocumentDB on every request, so the changes take effect immediately for new requests.

### Step 9: Verify Tool Access After Scope Change

Now test MCP access again with the LOB1 token. First initialize:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

This time you should see a successful initialization response from `docs-ai-search` v0.4.4! Now list the available tools:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list"
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see both tools listed (`search_cloudflare_documentation` and `migrate_pages_to_workers_guide`). The scope change granted LOB1 access to this MCP server.

Now call the **allowed** tool (`search_cloudflare_documentation`):

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "search_cloudflare_documentation",
      "arguments": {
        "query": "how to configure Workers"
      }
    }
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see actual Cloudflare documentation content about Workers configuration. Now try calling the **denied** tool (`migrate_pages_to_workers_guide`):

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/lob1-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "tools/call",
    "params": {
      "name": "migrate_pages_to_workers_guide",
      "arguments": {}
    }
  }'
:::

This should return a **403 Forbidden** — LOB1's scope only allows `search_cloudflare_documentation`. The gateway enforces tool-level access control even though the server itself would happily execute the tool.

::alert[This is the key takeaway: the MCP Gateway enforces **tool-level** access control. LOB1 can list both tools but can only invoke the one specified in their scope. This granularity lets platform teams expose servers to multiple teams while controlling exactly which capabilities each team can use.]{type="info"}

### Step 10: Verify in the Dashboard

1. **Logout** and **login** as `lob1-user` / `lob1pass`
2. Confirm you now see **3 servers** — Current Time API, MCP Gateway Tools, and Cloudflare Documentation

:image[lob1-user dashboard after scope update]{src="/static/img/module-3/3_3/registry_lob1_3_mcp.png" width=800}

The server card for Cloudflare Documentation shows **2 tools** — but remember, LOB1 can only invoke 1 of them. The card shows the total registered tools, not the per-user filtered count.

---

## What You Just Controlled

You modified access at two different levels:

| Control Plane | What You Changed | Effect |
|---------------|-----------------|--------|
| **Keycloak** (Part A) | Added `lob1-user` to `registry-users-lob2` group | User received LOB2's *existing* scope in addition to LOB1's |
| **DocumentDB** (Part B) | Updated the `registry-users-lob1` scope document | Changed *what LOB1's scope allows* — added the Cloudflare Documentation server with specific tool permissions |

These are independent controls:
- **Keycloak** answers: *which scopes apply to this user?*
- **DocumentDB** answers: *what does each scope permit?*

The scope document you imported controls all three layers of enforcement:

| Layer | Field | What You Set |
|-------|-------|-------------|
| **1 — UI Visibility** | `ui_permissions.list_service` | Which server cards appear in the dashboard |
| **2 — Method Access** | `server_access[].methods` | Which MCP protocol operations are allowed |
| **3 — Tool Permissions** | `server_access[].tools` | Which specific tools can be invoked via `tools/call` |

---

## Lab 3 Summary

| Step | What You Learned |
|------|------------------|
| **3.1** | Admin sees all 4 servers, 2 agents, 23 tools — the full platform view |
| **3.2** | LOB users see only their assigned servers, no agents — same registry, different views |
| **3.3** | You can modify access by changing Keycloak group membership (who gets which scope) or by updating scope documents via API (what each scope allows) |

### Key Takeaways

- **Group membership drives scope selection** — Keycloak groups map to DocumentDB scope documents
- **Scope documents define all three layers** — UI visibility, method access, and tool-level invocation permissions in a single JSON document
- **Changes are dynamic** — no code changes or redeployment needed. Group membership changes take effect on next login; scope document changes take effect immediately
- **Tool-level control is granular** — you can allow a user to see a server and list its tools, but restrict which specific tools they can invoke
- **The same model applies to M2M service accounts** — `lob1-bot` gets the same scopes as `lob1-user`
- **You governed the server you registered** — the Cloudflare Documentation server from Lab 2 is now accessible to LOB1, but only the search tool — not the migration guide

::alert[**Lab 3 Complete!** You've experienced and modified fine-grained access control at every layer of the MCP Gateway. In Lab 4, you'll integrate an AI coding assistant with the MCP Gateway to put all of this to practical use.]{type="success" header="Well Done!"}

:button[Continue to Lab 4: AI Coding Assistant Integration]{href="/module-4"}
