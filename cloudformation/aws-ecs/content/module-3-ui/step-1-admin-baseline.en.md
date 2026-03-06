---
title: "3.1 Admin Baseline: The Full View"
weight: 41
---

First, let's establish a baseline by seeing what the platform administrator can access. You'll record the full inventory of servers and agents — then compare it to the restricted views in the next step.

## Step 1: Login as Admin

::alert[**Use incognito/private browser windows for each user.** Keycloak's SSO session persists across logins, so clicking Logout and Login will silently re-authenticate you as the same user. Open a fresh incognito window for each account — this also lets you compare views side by side.]{type="warning"}

1. Open an **incognito/private browser window**
2. Navigate to your MCP Gateway URL
3. Click **Login** and authenticate as `admin`
4. Use the admin password from Secrets Manager (see [Lab 1, Step 1](/module-1/step-1-cloudformation-outputs) if you need a reminder)

:image[Admin dashboard showing all servers and agents]{src="/static/img/module-3/3_1/Registry_first_login.png" width=800}

## Step 2: Count the Servers

The admin user has the `registry-admins` scope with wildcard access (`server: "*"`), so every registered MCP server is visible. You should see **4 server cards** — including the Cloudflare Documentation server you registered in Lab 2:

| Server | Tools | Tags |
|--------|-------|------|
| **Current Time API** | 1 | time, timezone, datetime, api, utility |
| **AI Registry Tools** | 5 | registry, management, admin, gateway, mcp-tools |
| **Real Server Fake Tools** | 6 | demo, fake, tools, testing |
| **Cloudflare Documentation** | 2 | documentation, cloudflare, search, external |

::alert[The tool count on each card reflects the **total tools registered** on that server, not a per-user filtered count. Every user who can see a server card sees the same tool count — the difference is which tools they can actually *invoke*.]{type="info"}

## Step 3: Count the Agents

Scroll down or switch to the **Agents** tab. You should see **2 A2A agent cards**:

| Agent | Skills | Visibility |
|-------|--------|------------|
| **Flight Booking Agent** | 5 | public |
| **Travel Assistant Agent** | 4 | public |

These agents are registered with `public` visibility, but that doesn't mean every user can see them. Agent visibility is also controlled by the `list_agents` permission in each user's scope — as you'll see in the next step.

:image[Admin agents tab showing 2 agent cards]{src="/static/img/module-3/3_1/agents_view.png" width=800}

## Step 4: Record Your Baseline

Take note of these numbers — you'll compare them against the LOB user views:

| Metric | Admin Count |
|--------|-------------|
| MCP Servers | 4 |
| A2A Agents | 2 |
| Total Tools (across all servers) | 14 |

## Step 5: Preview IAM Settings

Before you start modifying access control, take a quick look at where the rules are managed in the UI.

1. Click **Settings** in the navigation bar, then select the **IAM** tab
2. You should see three sub-tabs: **Groups**, **Users**, and **M2M**
3. Select the **Groups** sub-tab — you'll see **12 pre-configured groups** listed in the table

:image[IAM Settings Groups tab showing 12 pre-configured groups]{src="/static/img/module-3-ui/3_1/iam_groups_overview.png" width=800}

4. Click the **pencil icon** on `registry-users-lob1` to preview its scope definition
5. You'll see the group's server access entries, method checkboxes, and tool selections — this is the visual representation of the scope document stored in DocumentDB
6. Click **cancel** without making any changes

This is the panel you'll use in Step 3 to modify access control — no terminal or API calls needed.

## What's Happening Behind the Scenes

When admin logs in, Keycloak returns a JWT with groups `["registry-admins", "mcp-registry-admin", "mcp-servers-unrestricted"]`. The Registry maps these to scopes that include:

- `ui_permissions.list_service: ["all"]` → every server card appears
- `ui_permissions.list_agents: ["all"]` → every agent card appears
- `server_access: [{ server: "*", methods: ["all"], tools: ["all"] }]` → unrestricted MCP access

This is the **platform administrator's view** — full visibility and full invocation rights. Regular LOB users will see a very different picture.

:button[Next: Login as LOB Users]{href="/module-3-ui/step-2-lob-users"}
