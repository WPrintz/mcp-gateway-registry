---
title: "2.3 Enable, Health Check & Test"
weight: 33
---

The Cloudflare Documentation server is registered but disabled. In this step, you'll enable it, verify it's healthy, and test the full MCP protocol flow — from session initialization to tool invocation.

## Step 1: Enable the Server

1. In the Registry dashboard (logged in as `admin`), find the **Cloudflare Documentation** server card
2. Click the **enable toggle** on the card to switch it from disabled to enabled
3. The gateway generates an nginx route for `/cloudflare-docs/` and reloads the proxy configuration

::alert[Enabling a server tells the gateway to create a reverse proxy route. MCP traffic to `/cloudflare-docs/mcp` will be forwarded to `https://docs.mcp.cloudflare.com/mcp`.]{type="info"}

## Step 2: Trigger a Health Check

1. Click the **refresh health** button (to the right of the search bar) to trigger health checks across all servers
2. Wait a few seconds for the health check to complete
3. The Cloudflare Documentation card should show a **healthy** status

The health check sends an MCP `initialize` request to the upstream server and verifies it responds with valid MCP protocol metadata.

After the health check completes, the card should also show the tool count:

| Server | Tools | Status |
|--------|-------|--------|
| Current Time API | 1 | ✅ Healthy |
| AI Registry Tools | 5 | ✅ Healthy |
| Real Server Fake Tools | 6 | ✅ Healthy |
| **Cloudflare Documentation** | **2** | ✅ Healthy |

You now have **4 MCP servers** and **14 total tools** in the registry.

---

## Step 3: Test via MCP Protocol (CLI)

Now let's verify the server works end-to-end through the MCP Gateway's reverse proxy. You'll use `curl` to send MCP protocol messages — the same way an AI agent would connect.

::alert[**Tip:** You can run these commands in AWS CloudShell. If you haven't used CloudShell yet, see [Step 1.1](/module-1/step-1-cloudformation-outputs) for instructions on how to open it from the AWS Console.]{type="info"}

### Get an Admin Token

First, set up your environment variables and get an authentication token:

:::code{language=bash showCopyAction=true}
export KEYCLOAK_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`KeycloakUrl`].OutputValue' --output text)
export GATEWAY_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`MCPGatewayUrl`].OutputValue' --output text)
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Gateway URL: $GATEWAY_URL"
:::

:::code{language=bash showCopyAction=true}
# Download the token helper script
curl -o get-m2m-token.sh https://raw.githubusercontent.com/agentic-community/mcp-gateway-registry/main/api/get-m2m-token.sh
chmod +x get-m2m-token.sh

# Get admin token
./get-m2m-token.sh --aws-region $AWS_REGION --keycloak-url $KEYCLOAK_URL --output-file /tmp/admin-token registry-admin-bot
:::

### Initialize an MCP Session

Send an `initialize` request to establish a session with the Cloudflare Documentation server through the gateway:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
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
        "name": "workshop-client",
        "version": "1.0.0"
      }
    }
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see a response like:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": { "listChanged": true },
      "prompts": { "listChanged": true }
    },
    "serverInfo": {
      "name": "docs-ai-search",
      "version": "0.4.4"
    }
  }
}
:::

The gateway successfully proxied your request to `https://docs.mcp.cloudflare.com/mcp` and returned the server's MCP capabilities.

### List Available Tools

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list"
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see the two tools:

1. **`search_cloudflare_documentation`** — Semantic search across Cloudflare docs
2. **`migrate_pages_to_workers_guide`** — Returns the Pages → Workers migration guide

### Invoke a Tool

Now call `search_cloudflare_documentation` to search Cloudflare's documentation:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/cloudflare-docs/mcp \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
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

You should see actual Cloudflare documentation content about Workers configuration. This confirms the full chain works:

```
Your curl → MCP Gateway (nginx) → Auth Server (validates token) → Cloudflare MCP Server → Response
```

::alert[**Token expiry:** M2M tokens have a 300-second TTL. If you get a 401 or 500 error, re-run the `get-m2m-token.sh` command to get a fresh token.]{type="warning"}

---

## Challenge: Register the AWS Knowledge MCP Server

You've now registered one external MCP server by following step-by-step instructions. Can you register a second one on your own?

**Your task:** Register the **AWS Knowledge MCP Server** — a fully managed, publicly available MCP server from AWS Labs that provides real-time access to AWS documentation, regional availability data, and architectural guidance.

**Documentation:** [AWS Knowledge MCP Server](https://awslabs.github.io/mcp/servers/aws-knowledge-mcp-server)

**Endpoint:** `https://knowledge-mcp.global.api.aws`

Using what you learned from registering the Cloudflare Documentation server, register this server, enable it, and verify it's healthy. The server exposes **5 tools** and uses the `streamable-http` transport — no authentication required.

::alert[**Check your tool count.** After enabling and running a health check, the server card should show **5 tools**. If it shows **0 tools**, the health check couldn't reach the MCP endpoint — check the hint below for a required configuration detail.]{type="warning"}

::::expand{header="Hint: Registration Details"}
| Field | Value |
|-------|-------|
| **Server Name** | `AWS Knowledge` |
| **Path** | `/aws-knowledge/` |
| **Proxy URL** | `https://knowledge-mcp.global.api.aws/` |
| **MCP Endpoint** *(optional field)* | `https://knowledge-mcp.global.api.aws/` |
| **Description** | `Search AWS documentation, get regional availability, and explore architectural guidance` |
| **Tags** | `aws, documentation, search, cloud, external` |

**Why is the MCP Endpoint needed?** By default, the Registry appends `/mcp` to the Proxy URL when performing health checks and MCP protocol calls (e.g., `https://knowledge-mcp.global.api.aws/mcp`). The AWS Knowledge MCP Server serves its MCP protocol at the **root path** (`/`), not at `/mcp`. Setting the MCP Endpoint field explicitly overrides this default behavior.

After registration:
1. Enable the server using the toggle on the card
2. Click the refresh health button to trigger a health check
3. The card should show **5 tools** and **healthy** status
::::

::::expand{header="Hint: Test via CLI"}
Use the same `curl` pattern from the Cloudflare test, but target the new server path:

:::code{language=bash showCopyAction=true}
curl -s -X POST $GATEWAY_URL/aws-knowledge/mcp \
  -H "Authorization: Bearer $(cat /tmp/admin-token)" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }' | grep "^data:" | sed 's/^data: //' | jq .
:::

You should see 5 tools: `aws___search_documentation`, `aws___read_documentation`, `aws___recommend`, `aws___list_regions`, and `aws___get_regional_availability`.
::::

---

## Step 4: Verify Semantic Search Includes the New Server

Go back to the Registry dashboard and try a semantic search:

1. Type `search developer documentation` and press **Enter**
2. The **Cloudflare Documentation** server should appear in the results

The embeddings generated during registration are working — the gateway can now discover this server through natural language queries.

---

## What You've Accomplished

You've completed the full server lifecycle:

| Phase | What Happened |
|-------|---------------|
| **Register** | Created a record in DocumentDB with connection details and metadata |
| **Embed** | Gateway generated vector embeddings from the server's name, description, and tags |
| **Enable** | Gateway created an nginx reverse proxy route to the upstream server |
| **Health Check** | Gateway verified the upstream server responds to MCP `initialize` |
| **Test** | You sent MCP protocol messages through the gateway and got real results |
| **Discover** | The server appeared in semantic search results |

Your registry now has 4 MCP servers with 14 total tools (5 servers with 19 tools if you completed the challenge). The new servers are fully operational — but currently only visible to the `admin` user. In Lab 3, you'll learn how to grant LOB users access to these servers using fine-grained access control.

---

## Lab 2 Summary

| Step | What You Learned |
|------|------------------|
| **2.1** | Keyword filtering vs semantic search — two complementary discovery modes |
| **2.2** | Different users see different search results based on their scope |
| **2.3** | How to register an external MCP server through the UI |
| **2.4** | How to enable, health-check, and test a server via the MCP protocol |
| **Challenge** | Register a second external MCP server (AWS Knowledge) independently |

### Key Takeaways

1. **Semantic search finds tools by meaning**, not just keywords — powered by vector embeddings
2. **Search results respect access control** — users only discover what they're authorized to see
3. **Registering a server** creates a record, generates embeddings, but doesn't route traffic until enabled
4. **The MCP Gateway proxies all traffic** — authentication, authorization, and routing happen transparently
5. **The `intelligent_tool_finder`** exposes the same search as an MCP tool for AI agents

::alert[**Lab 2 Complete!** You've discovered tools, registered a real external MCP server, and verified it works end-to-end. In Lab 3, you'll control who can access this server — and which specific tools they can invoke.]{type="success" header="Well Done!"}

:button[Continue to Lab 3: Fine-Grained Access Control]{href="/module-3"}
