---
title: "2.2 Register the Cloudflare Documentation Server"
weight: 32
---

You've explored what's already in the registry. Now you'll add something new — the **Cloudflare Documentation MCP Server**, a real external server that provides semantic search across all of Cloudflare's developer documentation.

## About the Cloudflare Documentation MCP Server

This is a publicly available MCP server maintained by Cloudflare. It exposes two tools:

| Tool | Description | Input |
|------|-------------|-------|
| `search_cloudflare_documentation` | Semantic search across all Cloudflare product docs | `{ "query": "string" }` |
| `migrate_pages_to_workers_guide` | Returns the Pages → Workers migration guide | None |

The server uses the `streamable-http` transport and requires no authentication for basic tool invocation — making it ideal for a workshop exercise.

::alert[This is a real, production MCP server at `https://docs.mcp.cloudflare.com/mcp`. The tools return actual Cloudflare documentation content.]{type="info"}

---

## Step 1: Navigate to Server Registration

1. Make sure you're logged in as `admin`
2. In the Registry dashboard, click the **Register Server** button in the top navigation

The registration form appears with fields for the server's connection details and metadata.

## Step 2: Fill in Server Details

Enter the following values in the registration form (fields are listed in the order they appear):

| Field | Value |
|-------|-------|
| **Server Name** | `Cloudflare Documentation` |
| **Path** | `/cloudflare-docs/` |
| **Proxy URL** | `https://docs.mcp.cloudflare.com/` |
| **Description** | `Search Cloudflare developer documentation using semantic search` |
| **Tags** | `documentation, cloudflare, search, external` |

::alert[The **Path** field determines the URL path where this server will be accessible through the MCP Gateway. After registration, MCP clients will send requests to `https://<gateway-url>/cloudflare-docs/mcp` to reach this server. Type the path exactly as shown — it is not auto-generated from the server name.]{type="info"}

Let's break down what each field means:

- **Server Name** — Human-readable label shown in the dashboard
- **Path** — The URL path segment for routing (must be unique, no spaces). Enter this exactly as shown above.
- **Proxy URL** — The actual upstream MCP server endpoint. The gateway proxies MCP protocol messages to this URL.
- **Description** — Used by semantic search to match queries to this server
- **Tags** — Comma-separated keywords for keyword filtering and categorization

## Step 3: Submit the Registration

1. Click **Register** (or **Submit**)
2. The server appears in the registry dashboard as a new card

::alert[The server starts in a **disabled** state with health status **unknown**. This is by design — newly registered servers need to be explicitly enabled and health-checked before they can accept MCP traffic. You'll do that in the next step.]{type="warning"}

## Step 4: Verify Registration in the Dashboard

After submitting, you should see a fourth server card in the dashboard:

| Server | Tools | Tags | Status |
|--------|-------|------|--------|
| Current Time API | 1 | time, timezone, datetime, api, utility | ✅ Healthy |
| MCP Gateway Tools | 14 | registry, management, admin, gateway, mcp-tools | ✅ Healthy |
| Real Server Fake Tools | 6 | demo, fake, tools, testing | ✅ Healthy |
| **Cloudflare Documentation** | — | documentation, cloudflare, search, external | ⏸️ Disabled |

The tool count for Cloudflare Documentation will show after the server is enabled and the gateway can query its `tools/list` endpoint.

---

## What Happened Behind the Scenes

When you clicked Register, the gateway:

1. **Created a registration record** in DocumentDB (`mcp_servers` collection) with the server name, path, proxy URL, and metadata
2. **Generated embeddings** from the server name, description, and tags — making it discoverable via semantic search
3. **Did NOT create an nginx route yet** — the server is disabled, so no traffic can reach it

The server is now *registered* but not *active*. In the next step, you'll enable it, trigger a health check, and test the MCP protocol end-to-end.

---

## Try Searching for It

Even before enabling the server, its embeddings are indexed. Try a semantic search:

1. Type `search cloudflare documentation` and press **Enter**
2. The **Cloudflare Documentation** server should appear in the results

The gateway can discover the server through search, but MCP protocol requests won't work until you enable it in the next step.

:button[Next: Enable, Health Check & Test]{href="/module-2/step-4-verify-server"}
