---
title: "Deep Dive: Authentication & Authorization Flow"
weight: 49
---

::alert[This page is a reference for security and network administrators. It traces the full authentication and authorization pipeline at the code level. You do not need to read this to complete the lab — it's here for those who want to understand exactly how every request is validated.]{type="info" header="Optional Reading"}

## Overview

Every request to the MCP Gateway passes through an authorization pipeline that spans three systems: **Keycloak** (identity), **Amazon DocumentDB** (permissions), and the **Auth Server** (enforcement). This page traces both the human-user and machine-to-machine (M2M) flows at the code level, showing exactly where each decision is made.

---

## System Components

| Component | Technology | Role |
|-----------|-----------|------|
| **Keycloak** | Runs on ECS, backed by Aurora PostgreSQL | Identity provider — authenticates users, issues JWTs, manages groups |
| **Auth Server** | Python FastAPI service (`auth_server/server.py`) | Reverse proxy gatekeeper — validates every MCP request before it reaches a server |
| **Registry API** | Python FastAPI service (`registry/`) | Dashboard backend — filters server/agent lists based on UI permissions |
| **DocumentDB** | Amazon DocumentDB (MongoDB-compatible) | Stores scope definitions (`mcp_scopes` collection), server registrations, agent registrations |
| **NGINX** | Reverse proxy | Routes requests, calls Auth Server via `auth_request` directive before forwarding to MCP servers |

---

## Keycloak Realm Configuration

The deployment creates a Keycloak realm called `mcp-gateway` with the following structure:

### Clients

| Client ID | Type | Flow | Purpose |
|-----------|------|------|---------|
| `mcp-gateway-web` | Confidential | Authorization Code (OAuth2) | Browser-based UI login |
| `mcp-gateway-m2m` | Confidential | Client Credentials | AI agent / automation authentication |
| `registry-admin-bot` | Confidential (Service Account) | Client Credentials | Admin-level M2M operations |
| `lob1-bot` | Confidential (Service Account) | Client Credentials | LOB 1 M2M operations |
| `lob2-bot` | Confidential (Service Account) | Client Credentials | LOB 2 M2M operations |

### Protocol Mapper: Groups Claim

Each client has an `oidc-group-membership-mapper` protocol mapper configured:

| Setting | Value |
|---------|-------|
| Mapper Type | `oidc-group-membership-mapper` |
| Claim Name | `groups` |
| Full Group Path | `false` |
| Add to ID Token | `true` |
| Add to Access Token | `true` |
| Add to Userinfo | `true` |

This mapper injects the user's Keycloak group memberships into the JWT as a `groups` claim — an array of group names. This is the bridge between Keycloak (identity) and DocumentDB (permissions).

### Groups and User Assignments

| User | Keycloak Groups | How They Authenticate |
|------|-----------------|----------------------|
| `admin` | `mcp-registry-admin`, `mcp-servers-unrestricted`, `registry-admins` | Browser (OAuth2) or self-signed JWT |
| `lob1-user` | `registry-users-lob1` | Browser (OAuth2) |
| `lob2-user` | `registry-users-lob2` | Browser (OAuth2) |
| `registry-admin-bot` (service account) | `registry-admins` | Client Credentials (M2M) |
| `lob1-bot` (service account) | `registry-users-lob1` | Client Credentials (M2M) |
| `lob2-bot` (service account) | `registry-users-lob2` | Client Credentials (M2M) |

---

## DocumentDB Scope Documents

Scope definitions live in the `mcp_scopes` collection. Each document maps Keycloak groups to specific permissions. Here are the scope documents relevant to this lab:

### registry-admins

:::code{language=json showCopyAction=false}
{
  "_id": "registry-admins",
  "group_mappings": ["registry-admins"],
  "server_access": [
    { "server": "*", "methods": ["all"], "tools": ["all"] }
  ],
  "ui_permissions": {
    "list_agents": ["all"],
    "get_agent": ["all"],
    "publish_agent": ["all"],
    "modify_agent": ["all"],
    "delete_agent": ["all"],
    "toggle_agent": ["all"],
    "health_check_agent": ["all"],
    "list_service": ["all"],
    "register_service": ["all"],
    "health_check_service": ["all"],
    "toggle_service": ["all"],
    "modify_service": ["all"]
  }
}
:::

Wildcard `"*"` on server, methods, and tools means unrestricted access to everything.

### registry-users-lob1

:::code{language=json showCopyAction=false}
{
  "_id": "registry-users-lob1",
  "group_mappings": ["registry-users-lob1"],
  "server_access": [
    {
      "server": "api",
      "methods": ["initialize", "GET"],
      "tools": ["servers", "agents"]
    },
    {
      "server": "currenttime",
      "methods": ["initialize", "notifications/initialized", "ping",
                  "tools/list", "tools/call", "resources/list",
                  "resources/templates/list"],
      "tools": ["current_time_by_timezone"]
    },
    {
      "server": "airegistry-tools",
      "methods": ["initialize", "notifications/initialized", "ping",
                  "tools/list", "tools/call", "resources/list",
                  "resources/templates/list"],
      "tools": ["intelligent_tool_finder"]
    }
  ],
  "ui_permissions": {
    "list_service": ["currenttime", "airegistry-tools"],
    "health_check_service": ["currenttime", "airegistry-tools"],
    "get_service": ["currenttime", "airegistry-tools"],
    "list_tools": ["currenttime", "airegistry-tools"],
    "call_tool": ["currenttime", "airegistry-tools"]
  }
}
:::

::alert[**Why does `api` server need `tools: ["servers", "agents"]`?** When the Registry UI makes REST API calls like `GET /api/servers`, the auth server parses the URL as: server=`api`, method=`servers`. The validation logic checks if `servers` is in either the `methods` array or the `tools` array. Since REST endpoints like `/api/servers` and `/api/agents` are treated as tools (not MCP methods), they must be listed in the `tools` array.]{type="info" header="Technical Note"}

LOB 1 can see two servers in the dashboard, call `tools/list` on both (sees all tools), but can only `tools/call` one specific tool on each.

### registry-users-lob2

:::code{language=json showCopyAction=false}
{
  "_id": "registry-users-lob2",
  "group_mappings": ["registry-users-lob2"],
  "server_access": [
    {
      "server": "api",
      "methods": ["initialize", "GET"],
      "tools": ["servers", "agents"]
    },
    {
      "server": "realserverfaketools",
      "methods": ["initialize", "notifications/initialized", "ping",
                  "tools/list", "tools/call", "resources/list",
                  "resources/templates/list"],
      "tools": ["quantum_flux_analyzer", "neural_pattern_synthesizer",
                "hyper_dimensional_mapper"]
    },
    {
      "server": "airegistry-tools",
      "methods": ["initialize", "notifications/initialized", "ping",
                  "tools/list", "tools/call", "resources/list",
                  "resources/templates/list"],
      "tools": ["intelligent_tool_finder"]
    }
  ],
  "ui_permissions": {
    "list_service": ["realserverfaketools", "airegistry-tools"],
    "health_check_service": ["realserverfaketools", "airegistry-tools"],
    "get_service": ["realserverfaketools", "airegistry-tools"],
    "list_tools": ["realserverfaketools", "airegistry-tools"],
    "call_tool": ["realserverfaketools", "airegistry-tools"]
  }
}
:::

LOB 2 can see two servers in the dashboard (Real Server Fake Tools and AI Registry Tools). They can call `tools/list` on both servers to see all available tools, but can only execute three specific tools on realserverfaketools via `tools/call`.

---

## Flow 1: Human User (Browser Login)

This is the flow when a user clicks **Login** in the Registry UI.

### Step 1: OAuth2 Authorization Code Flow

```
Browser                    Auth Server                 Keycloak
  │                            │                          │
  │  GET /oauth2/login/keycloak│                          │
  │───────────────────────────▶│                          │
  │                            │  302 Redirect to         │
  │                            │  /realms/mcp-gateway/    │
  │                            │  protocol/openid-connect/│
  │                            │  auth?client_id=         │
  │                            │  mcp-gateway-web&        │
  │                            │  response_type=code&     │
  │                            │  redirect_uri=...        │
  │◀───────────────────────────│                          │
  │                                                       │
  │  User authenticates at Keycloak login page            │
  │──────────────────────────────────────────────────────▶│
  │                                                       │
  │  302 Redirect with authorization code                 │
  │◀──────────────────────────────────────────────────────│
  │                            │                          │
  │  GET /oauth2/callback?code=│                          │
  │───────────────────────────▶│                          │
  │                            │  POST /token             │
  │                            │  (exchange code for JWT) │
  │                            │─────────────────────────▶│
  │                            │                          │
  │                            │  JWT with groups claim:  │
  │                            │  ["registry-users-lob1"] │
  │                            │◀─────────────────────────│
  │                            │                          │
  │  Set-Cookie:               │                          │
  │  mcp_gateway_session=...   │                          │
  │  (signed, contains         │                          │
  │   username + groups)       │                          │
  │◀───────────────────────────│                          │
```

The session cookie is signed with `SECRET_KEY` using `itsdangerous` and contains the username, groups, auth method, and provider. It expires after 8 hours.

### Step 2: Dashboard API Request (Server Listing)

When the browser loads the dashboard, it calls `GET /api/servers`. This request does **not** go through the Auth Server proxy — it goes directly to the Registry API:

```
Browser                    Registry API               DocumentDB
  │                            │                          │
  │  GET /api/servers          │                          │
  │  Cookie: mcp_gateway_...   │                          │
  │───────────────────────────▶│                          │
  │                            │                          │
  │                  enhanced_auth() dependency:          │
  │                  1. Decode session cookie             │
  │                  2. Extract groups                    │
  │                     ["registry-users-lob1"]           │
  │                            │                          │
  │                  map_cognito_groups_to_scopes():      │
  │                            │  Find docs where         │
  │                            │  group_mappings contains │
  │                            │  "registry-users-lob1"   │
  │                            │─────────────────────────▶│
  │                            │  Returns: scope          │
  │                            │  "registry-users-lob1"   │
  │                            │◀─────────────────────────│
  │                            │                          │
  │                  get_ui_permissions_for_user():       │
  │                            │  Get ui_permissions for  │
  │                            │  scope "registry-users-  │
  │                            │  lob1"                   │
  │                            │─────────────────────────▶│
  │                            │  Returns:                │
  │                            │  list_service:           │
  │                            │  ["currenttime",         │
  │                            │   "airegistry-tools"]    │
  │                            │◀─────────────────────────│
  │                            │                          │
  │                  get_servers_json():                  │
  │                  Filter server list where             │
  │                  technical_name IN                    │
  │                  accessible_services                  │
  │                            │                          │
  │  { "servers": [            │                          │
  │    { "display_name":       │                          │
  │      "Current Time API",   │                          │
  │      "num_tools": 1 },     │                          │
  │    { "display_name":       │                          │
  │      "AI Registry Tools",  │                          │
  │      "num_tools": 5 }      │                          │
  │  ]}                        │                          │
  │◀───────────────────────────│                          │
```

::alert[The `num_tools` value on each server card comes from the server registration, not from per-user filtering. LOB 1 sees "AI Registry Tools" with 5 tools displayed on the card, even though they can only invoke 1 of those 5.]{type="info"}

### Step 3: MCP Protocol Request (Tool Invocation)

When a user (or an AI coding assistant using a self-signed JWT) calls a tool through the MCP Gateway, the request goes through NGINX → Auth Server → MCP Server:

```
Client                 NGINX                Auth Server              MCP Server
  │                      │                       │                       │
  │ POST                 │                       │                       │
  │ /airegistry-tools/   │                       │                       │
  │ {"jsonrpc":"2.0",    │                       │                       │
  │  "method":"tools/call│                       │                       │
  │  "params":{          │                       │                       │
  │    "name":           │                       │                       │
  │    "intelligent_     │                       │                       │
  │     tool_finder",    │                       │                       │
  │    "arguments":{...}}│                       │                       │
  │  }                   │                       │                       │
  │─────────────────────▶│                       │                       │
  │                      │                       │                       │
  │                      │ GET /validate         │                       │
  │                      │ X-Original-URL:       │                       │
  │                      │   /airegistry-tools/  │                       │
  │                      │ X-Body: {...}         │                       │
  │                      │ Cookie: mcp_gw_...    │                       │
  │                      │──────────────────────▶│                       │
  │                      │                       │                       │
  │                      │  validate_request():                          │
  │                      │  1. Validate session cookie                   │
  │                      │     (calls map_groups_to_scopes)              │
  │                      │  2. Extract server=                           │
  │                      │     "airegistry-tools"                        │
  │                      │     from X-Original-URL                       │
  │                      │  3. Extract method="tools/call"               │
  │                      │     from JSON-RPC body                        │
  │                      │  4. Extract tool="intelligent_                │
  │                      │     tool_finder" from params.name             │
  │                      │                       │                       │
  │                      │  validate_server_tool_access():               │
  │                      │  - scope: registry-users-lob1                 │
  │                      │  - server "airegistry-tools"                  │
  │                      │    matches ✓                                  │
  │                      │  - method "tools/call" in methods ✓           │
  │                      │  - method IS "tools/call" →                   │
  │                      │    check tools array                          │
  │                      │  - "intelligent_tool_finder"                  │
  │                      │    in ["intelligent_tool_finder"] ✓           │
  │                      │  → ACCESS GRANTED                             │
  │                      │                       │                       │
  │                      │ 200 OK                │                       │
  │                      │ X-User: lob1-user     │                       │
  │                      │ X-Scopes: reg...lob1  │                       │
  │                      │◀──────────────────────│                       │
  │                      │                       │                       │
  │                      │ Forward request       │                       │
  │                      │──────────────────────────────────────────────▶│
  │                      │                       │                       │
  │                      │ Tool result           │                       │
  │                      │◀──────────────────────────────────────────────│
  │                      │                       │                       │
  │ Tool result          │                       │                       │
  │◀─────────────────────│                       │                       │
```

### What Happens When a Restricted Tool Is Called

If the same LOB 1 user tries to call a different tool on airegistry-tools:

```
  validate_server_tool_access():
  - scope: registry-users-lob1
  - server "airegistry-tools" matches ✓
  - method "tools/call" in methods ✓
  - method IS "tools/call" → check tools array
  - "server_health_check" NOT in ["intelligent_tool_finder"] ✗
  → ACCESS DENIED (403 Forbidden)
```

The request never reaches the MCP server. The Auth Server returns 403, and NGINX returns that to the client.

---

## Flow 2: M2M Agent (Client Credentials)

This is the flow when an AI agent authenticates using a service account.

### Step 1: Token Acquisition

```
Agent                                    Keycloak
  │                                         │
  │  POST /realms/mcp-gateway/protocol/     │
  │       openid-connect/token              │
  │  grant_type=client_credentials          │
  │  client_id=lob1-bot                     │
  │  client_secret=<secret>                 │
  │────────────────────────────────────────▶│
  │                                         │
  │  { "access_token": "<JWT>",             │
  │    "token_type": "bearer",              │
  │    "expires_in": 3600 }                 │
  │                                         │
  │  JWT payload includes:                  │
  │  { "groups": ["registry-users-lob1"],   │
  │    "azp": "lob1-bot",                   │
  │    "iss": ".../realms/mcp-gateway" }    │
  │◀────────────────────────────────────────│
```

The service account `lob1-bot` is assigned to the `registry-users-lob1` group in Keycloak. The groups mapper injects this into the JWT — identical to a human user's token.

### Step 2: MCP Request Through Gateway

```
Agent                  NGINX                Auth Server              MCP Server
  │                      │                       │                       │
  │ POST                 │                       │                       │
  │ /airegistry-tools/   │                       │                       │
  │ Authorization:       │                       │                       │
  │   Bearer <JWT>       │                       │                       │
  │ {"jsonrpc":"2.0",    │                       │                       │
  │  "method":"tools/call│                       │                       │
  │  ...}                │                       │                       │
  │─────────────────────▶│                       │                       │
  │                      │                       │                       │
  │                      │ GET /validate         │                       │
  │                      │ Authorization:        │                       │
  │                      │   Bearer <JWT>        │                       │
  │                      │ X-Original-URL:       │                       │
  │                      │   /airegistry-tools/  │                       │
  │                      │──────────────────────▶│                       │
  │                      │                       │                       │
  │                      │  validate_request():                          │
  │                      │  1. No session cookie                         │
  │                      │  2. Extract Bearer token                      │
  │                      │  3. keycloak_provider                         │
  │                      │     .validate_token(jwt)                      │
  │                      │     → validates RS256 signature               │
  │                      │       against Keycloak JWKS                   │
  │                      │     → extracts groups from claims             │
  │                      │  4. auth_method = "keycloak"                  │
  │                      │     → map_groups_to_scopes()                  │
  │                      │     → queries DocumentDB                      │
  │                      │  5. validate_server_tool_access()             │
  │                      │     (identical logic to human flow)           │
  │                      │                       │                       │
  │                      │ 200 OK                │                       │
  │                      │◀──────────────────────│                       │
  │                      │                       │                       │
  │                      │ Forward request       │                       │
  │                      │──────────────────────────────────────────────▶│
  │ Tool result          │                       │                       │
  │◀─────────────────────│                       │                       │
```

### Key Difference: Authentication Only

The **only** difference between human and M2M flows is how the identity is established:

| Aspect | Human (Browser) | M2M (Agent) |
|--------|----------------|-------------|
| **Authentication** | Session cookie (signed with `SECRET_KEY`, HS256) | JWT Bearer token (signed by Keycloak, RS256) |
| **Where groups come from** | Stored in session cookie at login time | Extracted from JWT `groups` claim at request time |
| **Where group→scope mapping happens** | Inside `validate_session_cookie()` | Inside `validate_request()` after token validation |
| **Scope validation** | `validate_server_tool_access()` | `validate_server_tool_access()` — same function |
| **Tool-level enforcement** | Identical | Identical |

Once the groups are extracted and mapped to scopes, the authorization logic is **exactly the same code path**. A `lob1-bot` service account and a `lob1-user` human get the same scopes, the same server access, and the same tool restrictions.

---

## Flow 3: Self-Signed JWT (Programmatic Access)

Human users can generate a self-signed JWT from the Registry UI for use with CLI tools and AI coding assistants. This is a third authentication path:

```
Browser                    Auth Server
  │                            │
  │  POST /generate-token      │
  │  Cookie: mcp_gateway_...   │
  │───────────────────────────▶│
  │                            │
  │  generate_user_token():    │
  │  1. Validate session cookie│
  │  2. Extract user's groups  │
  │     and scopes             │
  │  3. Sign JWT with          │
  │     SECRET_KEY (HS256)     │
  │  4. Include groups, scopes │
  │     in token claims        │
  │                            │
  │  { "token": "<self-signed  │
  │     JWT>",                 │
  │    "expires_in": 28800 }   │
  │◀───────────────────────────│
```

When this self-signed token is used in a request, the Auth Server detects `iss: "mcp-auth-server"` and validates it with `SECRET_KEY` instead of Keycloak's JWKS. The groups and scopes are embedded directly in the token — no DocumentDB lookup needed at validation time.

The permissions are identical to the user's browser session because the token is generated from the same groups.

---

## The validate_server_tool_access Algorithm

This is the core authorization function in `auth_server/server.py`. Every MCP request passes through it:

:::code{language=python showCopyAction=false}
async def validate_server_tool_access(server_name, method, tool_name, user_scopes):
    for scope in user_scopes:
        scope_config = await scope_repo.get_server_scopes(scope)
        for server_config in scope_config:
            if server_names_match(server_config['server'], server_name):
                allowed_methods = server_config.get('methods', [])
                has_wildcard = 'all' in allowed_methods or '*' in allowed_methods

                # Non-tools/call methods: method check only
                if (method in allowed_methods or has_wildcard) and method != 'tools/call':
                    return True  # ACCESS GRANTED

                # tools/call: must also check tool name
                allowed_tools = server_config.get('tools', [])
                has_wildcard_tools = 'all' in allowed_tools or '*' in allowed_tools
                if method == 'tools/call' and tool_name:
                    if tool_name in allowed_tools or has_wildcard_tools:
                        return True  # ACCESS GRANTED

    return False  # DEFAULT DENY
:::

Key behaviors:
- **Default deny** — if no scope grants access, the request is rejected
- **First match wins** — stops checking as soon as any scope grants access
- **`tools/list` does not filter tools** — it's a method-level check only, so all tools on the server are returned
- **`tools/call` checks the specific tool** — the tool name is extracted from the JSON-RPC `params.name` field
- **Wildcard support** — `"*"` or `"all"` in methods or tools grants unrestricted access

---

## Multi-Provider Support: Cognito, Entra ID, and Keycloak

This workshop uses Keycloak, but the MCP Gateway's auth architecture is **provider-agnostic**. The Auth Server uses a pluggable provider pattern — set the `AUTH_PROVIDER` environment variable to `keycloak`, `cognito`, or `entra`, and the same authorization pipeline works with any of them.

### How It Works

Each provider implements the same `AuthProvider` interface (`auth_server/providers/base.py`). The critical method is `validate_token()`, which returns a standardized result including a `groups` list. The only difference is where each provider finds the groups in the JWT:

| Provider | JWT Claim for Groups | Group Identifier Format |
|----------|---------------------|------------------------|
| **Keycloak** | `groups` | Group names (e.g., `"registry-users-lob1"`) |
| **Amazon Cognito** | `cognito:groups` | Group names (e.g., `"registry-users-lob1"`) |
| **Microsoft Entra ID** | `groups` | Object IDs / GUIDs (e.g., `"4c46ec66-a4f7-..."`) |

Once groups are extracted, the flow is identical — `map_groups_to_scopes()` queries DocumentDB, and `validate_server_tool_access()` enforces permissions. The provider doesn't matter after token validation.

### DocumentDB group_mappings: The Bridge

The `group_mappings` array in each scope document can contain **both** Keycloak/Cognito group names and Entra ID Object IDs simultaneously:

:::code{language=json showCopyAction=false}
{
  "_id": "registry-users-lob1",
  "group_mappings": [
    "registry-users-lob1",
    "4c46ec66-a4f7-4b62-9095-b7958662f4b6"
  ]
}
:::

This means you can migrate from Keycloak to Entra ID (or run both) without changing any scope definitions — just add the Entra ID group Object ID to the `group_mappings` array alongside the existing Keycloak group name.

### The Enforcement Path Is Identical

In `auth_server/server.py`, the group-to-scope mapping is triggered for all three providers:

:::code{language=python showCopyAction=false}
if user_groups and auth_method in ['keycloak', 'entra', 'cognito']:
    user_scopes = await map_groups_to_scopes(user_groups)
:::

From this point forward, the code doesn't know or care which IdP issued the token. The scopes drive everything.

---

## Summary: Where Each Decision Is Made

| Decision | Where | Code |
|----------|-------|------|
| Is this user who they claim to be? | **Keycloak** | OAuth2 flow or JWT signature validation |
| What groups does this user belong to? | **Keycloak** → JWT `groups` claim | `oidc-group-membership-mapper` |
| What scopes do those groups grant? | **DocumentDB** `mcp_scopes` collection | `map_groups_to_scopes()` → `scope_repo.get_group_mappings()` |
| Which servers appear in the dashboard? | **Registry API** | `get_ui_permissions_for_user()` → `ui_permissions.list_service` |
| Which agents appear in the dashboard? | **Registry API** | `get_ui_permissions_for_user()` → `ui_permissions.list_agents` |
| Can this user call this MCP method on this server? | **Auth Server** proxy | `validate_server_tool_access()` → `server_access[].methods` |
| Can this user invoke this specific tool? | **Auth Server** proxy | `validate_server_tool_access()` → `server_access[].tools` |
