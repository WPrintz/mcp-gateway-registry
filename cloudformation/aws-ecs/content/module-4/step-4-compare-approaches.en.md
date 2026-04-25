---
title: "4.4 Compare and Reflect"
weight: 54
---

Side-by-side comparison of the two approaches, followed by an access control test that proves the same scope rules from Lab 3 apply to AI assistants.

## Direct Connection vs. Virtual Server

| Dimension | Direct Connection (4.2) | Virtual Server (4.3) |
|-----------|----------------------|--------------------------|
| **Setup effort** | Find server, copy URL, write config per server | One virtual server endpoint, one config entry |
| **Token management** | One token per server | One token for all backends |
| **Adding servers** | New config entry, new token | Add a backend mapping to the virtual server |
| **Access control** | Managed per connection | Enforced centrally by the virtual server |
| **Observability** | No centralized logging | All requests logged through the virtual server |
| **Scalability** | Config grows linearly with servers | Constant — one entry, multiple backends |

Direct connections work for one-off debugging. For multi-server access, virtual servers are the way to go.

---

## Test Access Control with a Restricted User

Log in as a different user and see what happens when scope rules limit access. You'll work across three browser tabs: the **admin** Registry UI, a **lob1-user** Registry UI, and the **Code Editor** terminal.

### Step 1: See What lob1-user Can Access

1. Open the Registry UI in a **new browser tab** (or use an incognito/private window)
2. Click **Login with Keycloak** and log in as **lob1-user** with password **lob1pass**
3. Look at the server cards

:image[lob1-user sees only 2 servers]{src="/static/img/module-4/4_4/lob1-server-cards.png" width=800}

`lob1-user` belongs to `registry-users-lob1`. Based on the scope rules from Lab 3, this user can only see **Current Time API** and **AI Registry Tools**. Dev Tools, Real Server Fake Tools, and any other servers are not visible — the UI enforces the same access control.

Compare this to the admin view where all servers are visible.

### Step 2: Connect Claude Code with the LOB1 Token

Click the **gear icon** on the Current Time API card and copy the Claude Code `claude mcp add` command.

Back in the Code Editor terminal, remove the existing server and add the lob1-user config:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude mcp remove dev-tools
:::

Paste and run the `claude mcp add` command from the lob1-user gear icon.

### Step 3: Test the Restricted Access

Launch Claude Code:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude
:::

Try something the lob1-user is authorized for:

:::code{language=text showCopyAction=true}
What time is it in New York?
:::

This succeeds — the Current Time API is within the LOB1 scope.

Now go back to the lob1-user browser tab. Try to find Dev Tools or Real Server Fake Tools — they're not there. lob1-user can't even see the gear icon for servers outside their scope, so there's no way to configure Claude Code to access them. Access control prevents the connection from being set up in the first place.

Exit Claude Code:

:::code{language=text showCopyAction=true}
/exit
:::

::alert[The same scope rules control access whether the caller is a human in the UI or Claude Code connecting to an MCP server. If a user can't see a server in the UI, they can't get a token to connect an AI assistant to it either.]{type="info"}

---

## Restore the Admin Config

Before proceeding to Lab 5, restore the admin config:

1. Remove the lob1-user server:

:::code{language=bash showCopyAction=true}
cd ~/workshop
claude mcp remove current-time-api
:::

2. Switch back to the **admin browser tab** (or log out and click **Login with Keycloak** as `admin`)
3. Click the **gear icon** on the **Dev Tools** card, copy the Claude Code `claude mcp add` command, and run it in the terminal

Verify by launching Claude Code and checking `/mcp` — you should see `dev-tools` connected with 2 tools.

---

## Lab 4 Summary

| Step | What You Did |
|------|-------------|
| **4.1 Launch IDE** | Opened the Code Editor, verified Claude Code and Kiro CLI |
| **4.2 Direct Connection** | Connected Claude Code to a single MCP server via the gear icon |
| **4.3 Virtual Server** | Connected Claude Code and Kiro CLI to a virtual server with multiple backends |
| **4.4 Compare and Reflect** | Compared approaches, tested access control with a restricted user |

:button[Next: Lab 5 - Skills Registry]{href="/module-5/"}
