---
title: "3.3 Modify Access Control"
weight: 43
---

You've seen the effect of access control — now you'll change it. There are two control planes: **Keycloak** controls *who gets which scope*, and **DocumentDB** controls *what each scope allows*. You'll modify both — entirely through the IAM Settings panel in the UI.

::alert[**Prerequisite:** All four MCP servers must be **enabled** and showing **healthy** status before proceeding. If any server shows disabled or unhealthy, log in as `admin`, navigate to the dashboard, enable each server using the toggle, and refresh the health status. MCP protocol commands in this lab will return "405 Method Not Allowed" if the servers are not enabled and healthy.]{type="warning"}

## Part A: Change Group Membership via IAM Users Tab

First, you'll change *which scope applies* to a user by modifying their group membership through the IAM Settings panel. This replaces the Keycloak admin console workflow.

### Step 1: Navigate to IAM Users

1. Log in as `admin` (if not already logged in)
2. Click **Settings** in the navigation bar, then select the **IAM** tab
3. Select the **Users** sub-tab — you'll see a table listing all configured users

:image[IAM Settings Users tab showing user list]{src="/static/img/module-3-ui/3_3/iam_users_list.png" width=800}

### Step 2: Edit lob1-user's Group Membership

1. Find `lob1-user` in the table
2. Click the **pencil icon** to open the inline group editor
3. You'll see the current group assignment: `registry-users-lob1`

:image[Inline group editor for lob1-user with dropdown open]{src="/static/img/module-3-ui/3_3/iam_users_edit_groups.png" width=800}

### Step 3: Add a Second Group

1. In the group dropdown, search for `lob2`
2. Select `registry-users-lob2` from the results
3. Click **Save**

You should see a toast confirmation: **"Groups updated: 1 added, 0 removed"**

:image[Toast confirmation after saving group changes]{src="/static/img/module-3-ui/3_3/iam_users_edit_groups_saved.png" width=800}

### Step 3: Verify the Change

1. Switch to the MCP Gateway Registry tab
2. **Logout** and **login again** as `lob1-user` / `lob1pass` (the new group takes effect on next login)

You should now see **3 servers** — up from 2:

| Server | Before | After |
|--------|--------|-------|
| Current Time API | ✅ | ✅ |
| AI Registry Tools | ✅ | ✅ |
| Real Server Fake Tools | ❌ | ✅ |
| Cloudflare Documentation | ❌ | ❌ |

:image[lob1-user now sees 3 servers]{src="/static/img/module-3-ui/3_3/registry_lob1_3_mcp.png" width=800}

Notice that Cloudflare Documentation is still invisible — LOB 2's scope doesn't include it either. To grant access to the Cloudflare server, you need to modify the scope document itself.

::alert[No code was changed. No services were redeployed. A group membership change in the IAM Settings panel caused the authorization pipeline — JWT groups claim → DocumentDB scope lookup → UI filtering — to return a different result.]{type="info"}

---

## Part B: Modify Scope Permissions via IAM Groups Tab

Now you'll change *what a scope allows* by updating the scope definition through the IAM Groups tab. You'll grant LOB 1 access to the Cloudflare Documentation server you registered in Lab 2 — but with a twist: only the `search_cloudflare_documentation` tool, not `migrate_pages_to_workers_guide`.

### Step 4: Edit the LOB 1 Group Scope

1. Log back in as `admin`
2. Navigate to **Settings** > **IAM** > **Groups**
3. Find `registry-users-lob1` in the groups table
4. Click the **pencil icon** to open the group scope editor

:image[Group scope editor for registry-users-lob1]{src="/static/img/module-3-ui/3_3/iam_groups_edit_lob1.png" width=800}

### Step 5: Add the Cloudflare Documentation Server

1. In the Server Access section, click **"+ Add Server"**
2. From the server dropdown, select `cloudflare-docs`
3. Check the following method checkboxes: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`

:image[Adding cloudflare-docs server with method checkboxes]{src="/static/img/module-3-ui/3_3/iam_groups_server_access_add.png" width=800}

### Step 6: Select Allowed Tools

1. In the **Tools** dropdown for the `cloudflare-docs` entry, select only `search_cloudflare_documentation`
2. Leave `migrate_pages_to_workers_guide` unselected

:image[Tool dropdown with search_cloudflare_documentation selected]{src="/static/img/module-3-ui/3_3/iam_groups_tool_selector.png" width=800}

::alert[Notice you're granting `tools/list` (can browse what tools exist) but only one tool in the `tools` array. LOB1 users will be able to **see** both tools via `tools/list`, but can only **invoke** `search_cloudflare_documentation`. Calling `migrate_pages_to_workers_guide` will return 403 Forbidden.]{type="info"}

### Step 7: Review and Save

1. Check the **JSON Preview** panel on the right side of the editor — it shows the complete scope document that will be saved to DocumentDB
2. Verify the `cloudflare-docs` entry appears in `server_access` with the correct methods and tools
3. Verify `cloudflare-docs` appears in `ui_permissions.list_service`
4. Click **Save**

:image[JSON Preview showing the complete scope with cloudflare-docs]{src="/static/img/module-3-ui/3_3/iam_groups_json_preview.png" width=800}

You should see a toast confirmation indicating the scope was saved successfully. The scope changes are now in DocumentDB. The Auth Server queries DocumentDB on every request, so the changes take effect immediately for new requests.

### Step 8: Verify in the Dashboard

1. **Logout** and **login** as `lob1-user` / `lob1pass`
2. Confirm you now see **3 servers** — Current Time API, AI Registry Tools, and Cloudflare Documentation

:image[lob1-user dashboard after scope update]{src="/static/img/module-3-ui/3_3/registry_lob1_3_mcp.png" width=800}

The server card for Cloudflare Documentation shows **2 tools** — but remember, LOB1 can only invoke 1 of them. The card shows the total registered tools, not the per-user filtered count.

### Understanding Tool-Level Enforcement

The scope you just configured demonstrates all three enforcement scenarios for the Cloudflare Documentation server:

| MCP Method | Tool | Result | Why |
|-----------|------|--------|-----|
| `tools/list` | *(all)* | ✅ Allowed | `tools/list` is in the `methods` array — returns both tools |
| `tools/call` | `search_cloudflare_documentation` | ✅ Allowed | Tool is in the `tools` array |
| `tools/call` | `migrate_pages_to_workers_guide` | ❌ 403 Forbidden | Tool is **not** in the `tools` array |

This is the key takeaway: the MCP Gateway enforces **tool-level** access control. LOB1 can list both tools but can only invoke the one specified in their scope. This granularity lets platform teams expose servers to multiple teams while controlling exactly which capabilities each team can use.

You can verify this by reviewing the JSON Preview panel — the `tools` array under `cloudflare-docs` in `server_access` contains only `["search_cloudflare_documentation"]`, while the `methods` array includes `tools/list` (which returns all tools without filtering).

---

:::::tabs

::::tab{label="UI Verification (Default)"}

The UI verification you just performed (logging in as `lob1-user` and seeing 3 server cards) confirms that Layers 1 and 2 are working. The JSON Preview panel in the Groups editor confirms the tool-level restrictions for Layer 3.

::::

::::tab{label="Terminal Verification (Optional)"}

::alert[This section is optional. It provides terminal commands for learners who want to independently verify the 403 enforcement at the tool level. All access control changes have already been completed through the UI above.]{type="info"}

If you want to prove the tool-level enforcement using the MCP protocol directly, you can use the following commands in AWS CloudShell:

**1. Set environment variables:**

:::code{language=bash showCopyAction=true}
export KEYCLOAK_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`KeycloakUrl`].OutputValue' --output text)
export GATEWAY_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`MCPGatewayUrl`].OutputValue' --output text)
:::

**2. Get a LOB1 token:**

:::code{language=bash showCopyAction=true}
curl -o get-m2m-token.sh https://raw.githubusercontent.com/agentic-community/mcp-gateway-registry/main/api/get-m2m-token.sh
chmod +x get-m2m-token.sh
./get-m2m-token.sh --aws-region $AWS_REGION --keycloak-url $KEYCLOAK_URL --output-file /tmp/lob1-token lob1-bot
:::

**3. Call the allowed tool (should succeed):**

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

**4. Call the denied tool (should return 403):**

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

The first call returns Cloudflare documentation content. The second returns **403 Forbidden** — proving that the tool-level scope restriction you configured through the UI is enforced at the Auth Server proxy.

::::

:::::

---

## What You Just Controlled

You modified access at two different levels:

| Control Plane | What You Changed | Effect |
|---------------|-----------------|--------|
| **IAM > Users** (Part A) | Added `lob1-user` to `registry-users-lob2` group | User received LOB2's *existing* scope in addition to LOB1's |
| **IAM > Groups** (Part B) | Updated the `registry-users-lob1` scope definition | Changed *what LOB1's scope allows* — added the Cloudflare Documentation server with specific tool permissions |

These are independent controls:
- **IAM > Users** answers: *which scopes apply to this user?*
- **IAM > Groups** answers: *what does each scope permit?*

The scope definition you saved controls all three layers of enforcement:

| Layer | Field | What You Set |
|-------|-------|-------------|
| **1 — UI Visibility** | `ui_permissions.list_service` | Which server cards appear in the dashboard |
| **2 — Method Access** | `server_access[].methods` | Which MCP protocol operations are allowed |
| **3 — Tool Permissions** | `server_access[].tools` | Which specific tools can be invoked via `tools/call` |

::alert[**Ready to go further?** In Step 4, you'll use the IAM Settings panel to create entirely new groups, users, and M2M accounts — the full CRUD lifecycle through the UI.]{type="success" header="Nice work!"}

:button[Next: Create Groups, Users, and M2M Accounts]{href="/module-3-ui/step-4-create-group-user"}
