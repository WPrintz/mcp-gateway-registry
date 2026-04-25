---
title: "4.2 Direct Server Connection"
weight: 52
---

Connect Claude Code directly to a single MCP server — the Current Time API.

## Step 1: Get the Connection Config from the Registry UI

1. Open the `MCP_GATEWAY_URL` in a browser tab and click **Login with Keycloak**, then log in as `admin` with the `MCPGatewayAdminPassword` from the CloudFormation Outputs tab in Lab 1
2. Find the **Current Time API** server card — make sure it shows **Enabled** and **Healthy**
3. Click the **gear icon** on the card

::alert[If the Current Time API is disabled, click the enable/disable toggle on the card footer to enable it, then click **Refresh Health** to verify it's healthy.]{type="warning"}

The gear icon shows ready-to-use connection configs for different AI assistants. Find the **Claude Code** section — it contains a complete `claude mcp add` command with the endpoint URL and authentication token baked in:

:image[Gear icon showing Claude Code connection config]{src="/static/img/module-4/4_2/currenttime-gear-icon.png" width=800}

## Step 2: Add the MCP Server

Copy the `claude mcp add` command from the gear icon and paste it in the Code Editor terminal. It looks like this (your token will differ):

:::code{language=bash showCopyAction=false}
claude mcp add --transport http current-time-api https://<your-gateway>/currenttime/mcp \
  --header "X-Authorization: Bearer <token>"
:::

You should see output like:

:::code{language=text showCopyAction=false}
Added HTTP MCP server current-time-api with URL: https://<your-gateway>/currenttime/mcp to local config
Headers: {
  "X-Authorization": "Bearer eyJhbG..."
}
File modified: /home/participant/.claude.json [project: /home/participant/workshop]
:::

## Step 3: Test with Claude Code

Launch Claude Code from the workshop directory:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude
:::

On first launch, Claude Code walks through a one-time setup. Accept the defaults at each prompt:

1. **Theme** — select **Dark mode** (option 1)
2. **Security notes** — press **Enter** to continue
3. **Terminal setup** — select **Yes, use recommended settings** (option 1)
4. **Trust folder** — select **Yes, I trust this folder** (option 1)

::alert[These prompts only appear the first time you launch Claude Code. Subsequent launches skip straight to the prompt.]{type="info"}

Ask it to use the Current Time API:

:::code{language=text showCopyAction=true}
What time is it in Tokyo right now?
:::

Claude Code picks up the `current_time_by_timezone` tool from the config and invokes it. When prompted to approve the tool call, select **Yes** or **Yes, allow all edits during this session (shift+tab)**.

You should see output like:

:::code{language=text showCopyAction=false}
❯ What time is it in Tokyo right now?

● I'll check the current time in Tokyo for you.

● current-time-api - current_time_by_timezone (MCP)(tz_name: "Asia/Tokyo")
  ⎿  {
       "result": "2026-03-17 23:18:12 JST+0900"
     }

● The current time in Tokyo is 11:18 PM on March 17th, 2026 (JST).
:::

Exit Claude Code when done:

:::code{language=text showCopyAction=true}
/exit
:::

## What Worked — and What Doesn't Scale

You connected Claude Code to a single MCP server. But consider what it took:

1. **Browsed the UI** to find the server and its endpoint
2. **Copied the token** from the gear icon into a config file
3. **One server per config entry** — each server needs its own URL and token
4. **Adding a server** means another trip to the UI, another config entry

This works for one server. Next, you'll connect to a virtual server that routes to multiple backends through a single endpoint.

---

## Validation

You should now have:

- A `~/workshop/.mcp.json` file with the Current Time API configured
- Successfully asked Claude Code a time-related question and seen it invoke the `current_time_by_timezone` tool

:button[Next: Virtual Server]{href="/module-4/step-3-virtual-server"}
