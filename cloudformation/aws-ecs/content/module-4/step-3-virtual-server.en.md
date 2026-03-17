---
title: "4.3 Virtual Server"
weight: 53
---

Point Claude Code at the **Dev Tools** virtual server instead of an individual server. One endpoint, one token — it routes requests to multiple backends.

## Step 1: Get the Virtual Server Config

In the Registry UI (logged in as `admin`), find the **Dev Tools** card. This is a virtual server — it aggregates tools from multiple backend servers into a single MCP endpoint.

Click the **gear icon** on the Dev Tools card and find the **Claude Code** section:

:image[Dev Tools gear icon showing Claude Code config]{src="/static/img/module-4/4_3/dev-tools-gear-icon.png" width=800}

| Field | Value |
|-------|-------|
| **Endpoint** | `<MCP_GATEWAY_URL>/virtual/dev-tools/mcp` |
| **Backends** | Current Time API, AI Registry Tools |

## Step 2: Replace the Direct Connection

First, remove the Current Time API server you added in 4.2:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude mcp remove current-time-api
:::

You should see:

:::code{language=text showCopyAction=false}
Removed MCP server "current-time-api" from local config
File modified: /home/participant/.claude.json [project: /workshop]
:::

Now copy the `claude mcp add` command from the Dev Tools gear icon and run it. It looks like this (your token will differ):

:::code{language=bash showCopyAction=false}
claude mcp add --transport http dev-tools https://<your-gateway>/virtual/dev-tools/mcp \
  --header "X-Authorization: Bearer <token>"
:::

You should see:

:::code{language=text showCopyAction=false}
Added HTTP MCP server dev-tools with URL: https://<your-gateway>/virtual/dev-tools/mcp to local config
Headers: {
  "X-Authorization": "Bearer eyJhbG..."
}
File modified: /home/participant/.claude.json [project: /workshop]
:::

The difference from Step 4.2:

| | Direct (4.2) | Virtual Server (This Step) |
|---|---|---|
| **URL** | `/currenttime/mcp` (one server) | `/virtual/dev-tools/mcp` (multiple backends) |
| **Tools available** | `current_time_by_timezone` only | All tools from all mapped backends |
| **Config entries** | One per server | One total |

## Step 3: Test the Virtual Server

Launch Claude Code:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude
:::

Check that the virtual server connected and exposes tools from multiple backends. Type `/mcp`, select **dev-tools**, then **View tools**:

:::code{language=text showCopyAction=true}
/mcp
:::

You should see:

:::code{language=text showCopyAction=false}
Tools for dev-tools
2 tools

  1. current_time_by_timezone
  2. intelligent_tool_finder
:::

One endpoint, two tools from two different backend servers. Press **Esc** to return to the prompt.

Now use a tool through the virtual server — same tool as 4.2, but routed through a different path:

:::code{language=text showCopyAction=true}
What time is it in London?
:::

When prompted to approve the tool call, select **Yes, and don't ask again for dev-tools - current_time_by_timezone commands** (option 2).

You should see:

:::code{language=text showCopyAction=false}
● dev-tools - current_time_by_timezone (MCP)(tz_name: "Europe/London")
  ⎿  {
       "result": "2026-03-17 15:21:12 GMT+0000"
     }

● The current time in London is 3:21:12 PM GMT on March 17, 2026.
:::

Same config, same endpoint — the virtual server routes `current_time_by_timezone` to the Current Time API backend.

::alert[If the tool call fails with an error, your token may have expired. Go back to the Dev Tools gear icon in the Registry UI, copy a fresh `claude mcp add` command, and re-run it.]{type="warning"}

Exit Claude Code:

:::code{language=text showCopyAction=true}
/exit
:::

## Step 4: Try with Kiro CLI

The same virtual server endpoint works with any MCP-compatible assistant. Configure Kiro CLI to connect:

:::code{language=bash showCopyAction=true}
mkdir -p ~/workshop/.kiro/settings
:::

On the **Dev Tools** card, click the gear icon again and select the **Kiro** tab. Copy the JSON config and save it to the Kiro settings file. The JSON from the gear icon looks like this (your token will differ):

:::code{language=json showCopyAction=false}
{
  "mcpServers": {
    "dev-tools": {
      "url": "https://<your-gateway>/virtual/dev-tools/mcp",
      "headers": {
        "X-Authorization": "Bearer <token>"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
:::

Paste it using the heredoc command:

:::code{language=bash showCopyAction=true}
cat > ~/workshop/.kiro/settings/mcp.json << 'PASTE'
<PASTE THE KIRO GEAR ICON JSON HERE>
PASTE
:::

Launch Kiro CLI (already authenticated with AWS Builder ID in Step 4.1):

:::code{language=bash showCopyAction=true}
cd ~/workshop
kiro-cli chat
:::

Ask the same question:

:::code{language=text showCopyAction=true}
What time is it in Paris?
:::

When prompted to allow the action, press **t** to trust the tool for the session. You should see:

:::code{language=text showCopyAction=false}
Running tool current_time_by_timezone with the param (from mcp server: dev-tools)
 {
   "tz_name": "Europe/Paris"
 }

> It's 4:27 PM in Paris (CET+1).
:::

Same endpoint, same access control — different assistant. Exit with `/exit`.

---

## What Happened Behind the Scenes

```
+-----------------------+
|  Claude Code          |--+
|  .mcp.json            |  |  +-----------------------+     +-----------------------+
+-----------------------+  +->|  Dev Tools            |---->|  Current Time API     |
+-----------------------+  |  |  Virtual Server       |     +-----------------------+
|  Kiro CLI             |--+  |  /virtual/dev-tools/  |---->|  AI Registry Tools    |
|  .kiro/settings/      |     +-----------------------+     +-----------------------+
|  mcp.json             |
+-----------------------+
```

| Step | What Happens |
|------|-------------|
| **Tool discovery** | The assistant calls `tools/list` on the virtual server |
| **Tool aggregation** | The virtual server returns tools from all mapped backends |
| **Tool routing** | When the assistant calls a tool, the virtual server routes it to the correct backend |
| **Access control** | The virtual server validates the token and enforces scope rules |

---

## Validation

You should now have:

- A `~/workshop/.mcp.json` with the Dev Tools virtual server configured for Claude Code
- A `~/workshop/.kiro/settings/mcp.json` with the same endpoint configured for Kiro CLI
- Verified the virtual server exposes tools from multiple backends via `/mcp`
- Used `current_time_by_timezone` routed through the virtual server
- Successfully queried from both Claude Code and Kiro CLI

:button[Next: Compare and Reflect]{href="/module-4/step-4-compare-approaches"}
