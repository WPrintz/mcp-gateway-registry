---
title: "Lab 3: Fine-Grained Access Control"
weight: 40
---

In this lab, you'll experience multi-tenancy in action by logging in as different line-of-business (LOB) users. You'll see how the MCP Gateway enforces group-based visibility at three distinct layers — controlling which servers you can **see**, which MCP methods you can **call**, and which individual tools you can **invoke**.

**Estimated Time:** 25 minutes

## What You'll Learn

- How different users see different MCP servers and agents based on group membership
- How the MCP Gateway enforces access control at three layers: UI visibility, method access, and tool-level permissions
- Where access control records are stored and how they connect
- How the same model applies to both human users and M2M service accounts (AI agents)
- How to create groups, users, and M2M accounts through the IAM Settings panel

## Prerequisites

- Completed Lab 1 (familiar with the Registry UI and login process)
- Completed Lab 2 (Cloudflare Documentation server registered, enabled, and healthy)
- Access to the pre-configured user accounts

::alert[This module uses the **IAM Settings panel** (Settings > IAM) for all access control changes. You will not need a terminal, the Keycloak admin console, or curl commands. Every modification — group membership, scope definitions, user creation, and M2M account management — is done through the UI.]{type="info" header="UI-Based Workflow"}

---

## How Authentication Works

Before you start switching between users, it helps to understand the authentication and authorization pipeline. In this workshop implementation, the MCP Gateway uses **Keycloak** as its identity provider and **Amazon DocumentDB** to store fine-grained permission rules.

### Keycloak: Identity and Group Membership

Keycloak manages a dedicated realm called `mcp-gateway` that was automatically configured during deployment. It contains:

| Component | Purpose | Examples |
|-----------|---------|----------|
| **Users** | Human identities that log in via the UI | `admin`, `lob1-user`, `lob2-user` |
| **Groups** | Organizational units that users belong to | `registry-admins`, `registry-users-lob1` |
| **Clients** | Applications that authenticate against Keycloak | `mcp-gateway-web` (browser), `mcp-gateway-m2m` (agents) |
| **Service Accounts** | Machine identities for AI agents and automation | `registry-admin-bot`, `lob1-bot`, `lob2-bot` |

When a user logs in, Keycloak issues a JWT token that includes a `groups` claim — a list of every Keycloak group the user belongs to. This is the starting point for all authorization decisions.

::alert[This workshop uses Keycloak, but the MCP Gateway supports **Amazon Cognito** and **Microsoft Entra ID** as drop-in replacements. The authorization pipeline is IdP-agnostic — only the `AUTH_PROVIDER` environment variable changes. See the [Deep Dive: Authentication & Authorization Flow](/module-3-ui/deep-dive-auth-flow) for details on multi-provider support.]{type="info"}

### DocumentDB: Scope Definitions

Keycloak knows *who you are* and *what groups you belong to*. But it doesn't know what those groups mean in terms of MCP server access. That mapping lives in Amazon DocumentDB, in a collection called `mcp_scopes`.

Each scope document maps a Keycloak group to three types of permissions:

| Field | What It Controls |
|-------|-----------------|
| `group_mappings` | Which Keycloak groups (or Entra ID Object IDs) activate this scope |
| `ui_permissions` | Which servers and agents appear in the dashboard |
| `server_access` | Which MCP servers, methods, and individual tools are allowed |

### The Authentication Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│  1. USER LOGS IN                                                         │
│     Browser → Keycloak (mcp-gateway realm)                               │
│     Keycloak authenticates user, returns JWT with groups claim           │
│     Example: groups = ["registry-users-lob1"]                            │
├──────────────────────────────────────────────────────────────────────────┤
│  2. GROUPS → SCOPES (DocumentDB lookup)                                  │
│     Registry queries mcp_scopes collection:                              │
│     "Find all scope docs where group_mappings contains                   │
│      'registry-users-lob1'"                                              │
│     Result: scope "registry-users-lob1" with its server_access           │
│     and ui_permissions                                                   │
├──────────────────────────────────────────────────────────────────────────┤
│  3. SCOPES → PERMISSIONS (three layers of enforcement)                   │
│                                                                          │
│     Layer 1 — UI Visibility (Registry API)                               │
│       ui_permissions.list_service → which server cards appear            │
│       ui_permissions.list_agents  → which agent cards appear             │
│                                                                          │
│     Layer 2 — Method Access (Auth Server proxy)                          │
│       server_access[].methods → which MCP protocol methods               │
│       are allowed (initialize, tools/list, tools/call, etc.)             │
│                                                                          │
│     Layer 3 — Tool Permissions (Auth Server proxy)                       │
│       server_access[].tools → for tools/call, which specific             │
│       tools can be invoked                                               │
└──────────────────────────────────────────────────────────────────────────┘
```

::alert[The authentication flow is identical for human users and M2M service accounts. A `lob1-bot` service account gets the same scopes and restrictions as a `lob1-user` human. The only difference is how they authenticate (OAuth2 vs Client Credentials). See the [Deep Dive: Authentication & Authorization Flow](/module-3-ui/deep-dive-auth-flow) page for a code-level trace of both paths.]{type="info"}

---

## Three Layers of Access Control

The MCP Gateway enforces permissions at every layer of the stack:

### Layer 1: UI Visibility — What You See

The `ui_permissions` field in each scope document controls what appears in the dashboard. When the Registry API builds the server list, it checks the user's `list_service` permissions and only returns matching servers. The same applies to agents via `list_agents`.

::alert[A user who cannot see a server in the dashboard also cannot discover it through the API. The filtering happens server-side.]{type="info"}

### Layer 2: Method Access — What Protocols You Can Use

Even if a user can see a server, they may not be able to use all MCP protocol methods on it. The `methods` array in each `server_access` rule controls which operations are allowed:

| Method | Purpose |
|--------|---------|
| `initialize` | Establish MCP session with the server |
| `tools/list` | List available tools on the server |
| `tools/call` | Execute a specific tool |
| `resources/list` | List available resources |
| `ping` | Health check |

A user might have `tools/list` (can browse what tools exist) but not `tools/call` (cannot execute them). This is enforced by the Auth Server, which sits as a reverse proxy in front of every MCP server.

### Layer 3: Tool Permissions — What You Can Invoke

This is the most granular layer. When a user calls `tools/call`, the Auth Server extracts the specific tool name from the JSON-RPC request payload and checks it against the `tools` array in the scope's `server_access` rule.

For example, LOB 1 users connecting to the AI Registry Tools server:
- Can call `tools/list` → sees all 5 tools on the server
- Can call `tools/call` for `intelligent_tool_finder`
- Cannot call `tools/call` for any of the other 4 tools → gets **403 Forbidden**

::alert[The `tools/list` response shows all tools registered on the server — it does not filter by user permissions. This is by design: users can discover what exists, but can only invoke what they're authorized for. The enforcement happens at the `tools/call` layer.]{type="warning"}

---

## Where Records Are Stored

| Data | Storage | Purpose |
|------|---------|---------|
| Users, groups, group memberships | **Keycloak** (backed by Aurora PostgreSQL) | Identity: *who you are* and *what groups you belong to* |
| Scope definitions (group→server→method→tool mappings) | **Amazon DocumentDB** (`mcp_scopes` collection) | Authorization: *what your groups can do* |
| MCP server registrations | **Amazon DocumentDB** (`mcp_servers` collection) | Registry: *what servers exist* |
| A2A agent registrations | **Amazon DocumentDB** (`mcp_agents` collection) | Registry: *what agents exist* |

Keycloak and DocumentDB work together. Keycloak handles authentication and group membership. DocumentDB holds the fine-grained rules that translate group membership into specific server, method, and tool permissions.

---

## Workshop Scenario

Your enterprise has two lines of business, each with their own set of AI tools. A shared utility server (`AI Registry Tools`) is available to both teams, and the platform administrator has access to everything — including the Cloudflare Documentation server you registered in Lab 2.

| Line of Business | Keycloak Group | Exclusive Servers | Shared Servers |
|------------------|----------------|-------------------|----------------|
| **LOB 1** | `registry-users-lob1` | Current Time API | AI Registry Tools |
| **LOB 2** | `registry-users-lob2` | Real Server Fake Tools | AI Registry Tools |

The platform administrator (`admin`) can see everything — all 4 servers, all agents, all tools. Neither LOB user can see the Cloudflare Documentation server yet — you'll change that in Step 3.

## Workshop Pre-Configured Users

| Username | Password | Keycloak Groups | What They See |
|----------|----------|-----------------|---------------|
| `admin` | *(from Secrets Manager)* | `registry-admins`, `mcp-registry-admin`, `mcp-servers-unrestricted` | All 4 MCP servers, all 2 A2A agents, all tools |
| `lob1-user` | `lob1pass` | `registry-users-lob1` | 2 servers (Current Time API, AI Registry Tools), 0 agents |
| `lob2-user` | `lob2pass` | `registry-users-lob2` | 2 servers (Real Server Fake Tools, AI Registry Tools), 0 agents |

### What Each User Can Invoke

Beyond visibility, each user has different tool-level permissions:

| User | Server | Can List Tools | Can Invoke |
|------|--------|---------------|------------|
| `admin` | All servers | All tools | All tools |
| `lob1-user` | Current Time API | 1 tool | `current_time_by_timezone` |
| `lob1-user` | AI Registry Tools | 5 tools | `intelligent_tool_finder` only |
| `lob2-user` | Real Server Fake Tools | 6 tools | 3 tools (`quantum_flux_analyzer`, `neural_pattern_synthesizer`, `hyper_dimensional_mapper`) |
| `lob2-user` | AI Registry Tools | 5 tools | `intelligent_tool_finder` only |

::alert[Notice that both LOB users can **see** all tools on AI Registry Tools via `tools/list`, but can only **invoke** `intelligent_tool_finder`. The other 4 tools return 403 Forbidden at the Auth Server proxy.]{type="info"}

### M2M Service Accounts

The same access control model applies to AI agents using machine-to-machine (M2M) authentication:

| Service Account | Keycloak Group | Same Permissions As |
|-----------------|----------------|---------------------|
| `registry-admin-bot` | `registry-admins` | `admin` user |
| `lob1-bot` | `registry-users-lob1` | `lob1-user` |
| `lob2-bot` | `registry-users-lob2` | `lob2-user` |

These service accounts authenticate via OAuth2 Client Credentials flow and receive the same group-based permissions as their human counterparts.

---

## Steps

::children
