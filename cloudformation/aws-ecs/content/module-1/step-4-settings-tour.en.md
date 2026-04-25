---
title: "1.4 Explore the Settings"
weight: 24
---

The dashboard shows you what's registered — servers, agents, tools. The **Settings** page is the admin control plane for audit logging, federation, virtual servers, identity management, and system configuration.

::alert[The Settings page is **admin-only**. You must be logged in as `admin` to access it. If you're logged in as a different user, log out and sign back in as `admin` before continuing.]{type="warning" header="Admin Access Required"}

## Accessing Settings

In the top header bar, click the **gear icon** (⚙) near the user menu. This opens the Settings page with six menu items.

:image[Settings Sidebar]{src="/static/img/module-1/1_4/settings_sidebar.png" width=800}

## Settings Overview

| Menu Item | Purpose | Admin Only | Explored In |
|-----------|---------|:----------:|-------------|
| **Audit** | View and export API and MCP access logs | Yes | This step |
| **Federation** | Configure peer registry sync and discovery | Yes | Module 2 (Lab 2.3) |
| **Virtual MCP** | Create composite servers from existing tools | Yes | Module 2 (Lab 2.2) |
| **IAM** | Manage groups, users, and machine-to-machine credentials | Yes | Module 3 |
| **Notifications** | Notification settings (future feature) | Yes | This step |
| **System Config** | View and export all platform configuration | Yes | This step |

---

## 1. Audit

The Audit page provides a real-time view of every API call and MCP tool invocation that flows through the platform. In an enterprise environment, this is your compliance and troubleshooting backbone.

:image[Audit Log Viewer]{src="/static/img/module-1/1_4/settings_audit.png" width=800}

**Key features:**

- **Two log streams** — switch between *Registry API Logs* (server registrations, config changes, user actions) and *MCP Access Logs* (tool invocations, gateway proxy requests)
- **Filtering** — filter by timestamp, user, action type, or status code to narrow down events
- **Credential masking** — sensitive values like tokens and API keys are automatically redacted in log entries
- **Export** — download logs in JSONL or CSV format for offline analysis or SIEM ingestion
- **Dual storage** — logs are written to both local files and MongoDB, so you have redundancy built in

**Connection to the dashboard:** Every action you've taken so far — logging in, enabling servers, running searches — has been recorded here. The Audit page lets you see the trail.

**Try this:** Look at the most recent log entries. Can you find the login event from when you signed in as `admin`? Try switching between the two log stream tabs.

::alert[Audit logs are essential for SOC 2, HIPAA, and other compliance frameworks. The dual-storage approach (file + database) ensures logs survive even if one storage backend has issues.]{type="info"}

---

## 2. Federation

Federation lets your registry discover and sync servers from **peer registries** — other MCP Gateway instances or public registries like Anthropic's. Instead of manually registering every server, federation brings external catalogs to your doorstep.

:image[Federation Configuration]{src="/static/img/module-1/1_4/settings_federation.png" width=800}

**Key features:**

- **Peer-to-peer sync** — connect to other MCP Gateway Registry instances to share server catalogs bidirectionally
- **Anthropic public registry** — sync with Anthropic's official MCP server registry to discover community and first-party servers
- **Sync modes** — choose between manual sync, scheduled intervals, or event-driven sync
- **Encrypted credentials** — peer authentication credentials are encrypted at rest using Fernet symmetric encryption
- **Orphan detection** — when a peer removes a server, federation detects the orphan and can auto-clean or flag it
- **Path namespacing** — federated servers are mounted under namespaced paths to avoid route collisions with local servers

**Connection to the dashboard:** Remember the **External Registries** tab from the previous step? Federation is what populates it. Servers discovered through federation appear there, ready to be imported into your local registry.

**Try this:** Look at the pre-configured federation sources. You should see at least one peer (ASOR) and the Anthropic public registry. Note the sync status and last sync timestamp for each source.

::alert[Federation credentials are encrypted using Fernet keys derived from the platform's secret configuration. Never share federation peer tokens — they grant read access to your server catalog.]{type="warning"}

---

## 3. Virtual MCP

Virtual MCP servers let you **compose tools from multiple backend servers** into a single endpoint. Instead of connecting an AI agent to five different servers, you create one virtual server that exposes exactly the tools that agent needs.

:image[Virtual MCP Configuration]{src="/static/img/module-1/1_4/settings_virtual_mcp.png" width=800}

**Key features:**

- **Tool aggregation** — select individual tools from any registered MCP server and bundle them into a virtual endpoint
- **Tool aliasing** — rename tools to avoid naming conflicts or provide clearer names for agents (e.g., rename `get_data` from two different servers to `get_sales_data` and `get_inventory_data`)
- **Version pinning** — lock a virtual server to a specific backend server version so upstream updates don't break your agent workflows
- **Per-tool scopes** — restrict individual tools within a virtual server to specific user groups, even if the underlying server is broadly accessible
- **Session multiplexing** — a single virtual server session manages connections to multiple backend servers transparently

**Connection to the dashboard:** The **Dev Tools** virtual server you explored in the previous step was created through this Settings page. Here you can see how its tools were selected from the CurrentTime and AI Registry Tools backends.

**Try this:** Look at the Dev Tools virtual server configuration. Notice how `current_time_by_timezone` is sourced from `/currenttime/` and `intelligent_tool_finder` from `/airegistry-tools/`. Consider what other tool combinations might be useful for specific teams.

::alert[Virtual servers are a powerful governance tool. By curating which tools each team can access through a virtual endpoint, you enforce least-privilege access without modifying the underlying MCP servers.]{type="info"}

---

## 4. IAM (Identity and Access Management)

IAM is where you manage **who can access what**. It has three sub-tabs: Groups, Users, and M2M (Machine-to-Machine).

:image[IAM Configuration]{src="/static/img/module-1/1_4/settings_iam.png" width=800}

**Key features:**

- **Groups** — define access scopes by mapping groups to MCP server paths. A user in the `registry-users-lob1` group only sees servers assigned to that group. Groups also control UI permissions (who can register servers, manage users, etc.)
- **Users** — view and manage user accounts synced from Keycloak. See each user's group memberships and last login
- **M2M (Machine-to-Machine)** — create credentials for automated agents, CI/CD pipelines, and service accounts that need API access without a human login. M2M clients authenticate via OAuth2 client credentials flow

**Pre-configured groups:**

| Group | Servers Accessible | UI Permissions |
|-------|-------------------|----------------|
| `registry-admins` | All servers | Full admin access |
| `registry-users-lob1` | Current Time API, AI Registry Tools | Read and execute |
| `registry-users-lob2` | Real Server Fake Tools, AI Registry Tools | Read and execute |

**Pre-configured users:** `admin`, `testuser`, `registry-users-lob1`, `registry-users-lob2` — each mapped to their respective groups through Keycloak.

**Pre-configured M2M clients:** The workshop includes pre-registered M2M bot credentials that you'll use in Module 3 to test programmatic API access.

**Connection to the dashboard:** IAM controls what each user sees on the dashboard. When `registry-users-lob1` logs in, they only see servers assigned to the `registry-users-lob1` group. This is the access control engine behind the filtered views.

**Try this:** Click the **Groups** tab and examine the `registry-users-lob1` group by clicking the pencil icon. Note which server paths are assigned. Then check the **Users** tab to see how `registry-users-lob1` is mapped to that group.

::alert[You'll work hands-on with IAM in Module 3, where you'll create new groups, assign servers, and test access control by switching between different user accounts.]{type="info"}

---

## 5. Notifications

The Notifications section is a **placeholder for a future feature**. When implemented, it will allow admins to configure alerts for events like server health changes, federation sync failures, or access policy violations.

::alert[Notifications is not yet active in this workshop version. No configuration is needed here — just note its presence for future reference.]{type="info"}

---

## 6. System Config

System Config provides a **read-only view of every configuration parameter** that drives the platform. This is your single source of truth for understanding how the current deployment is configured.

:image[System Config]{src="/static/img/module-1/1_4/settings_system_config.png" width=800}

**Key features:**

- **11 configuration groups** — organized into logical sections: Server, Auth, Database, Federation, Security, Gateway, Logging, Features, Rate Limits, Notifications, and Advanced
- **Sensitive value masking** — passwords, API keys, and secrets are masked with `***` in the display. Only the config key names are visible
- **Search and filter** — quickly find specific configuration keys across all groups
- **4 export formats** — export the full configuration (with masked secrets) as ENV, JSON, TFVARS, or YAML for documentation or infrastructure-as-code workflows
- **Rate-limited** — export operations are rate-limited to prevent abuse
- **Read-only** — configuration cannot be changed through this page. Changes require updating environment variables or CloudFormation parameters and redeploying

**Try this:** Use the search bar to find `AUTH_SERVER_URL`. Notice how it shows the full URL to your Keycloak instance. Then try searching for `SECRET` — all matching values will be masked. Try exporting in JSON format to see the complete configuration structure.

::alert[System Config is read-only by design. In a production deployment, configuration changes flow through infrastructure-as-code (CloudFormation, Terraform) to maintain auditability and reproducibility.]{type="info"}

---

## Enterprise Value Map

Understanding how Settings maps to enterprise governance needs:

| Governance Need | Settings Feature | How It Helps |
|----------------|-----------------|--------------|
| **Compliance auditing** | Audit | Immutable logs with credential masking, JSONL/CSV export for SIEM |
| **Multi-org tool sharing** | Federation | Peer sync with encrypted credentials, orphan detection |
| **Least-privilege access** | Virtual MCP + IAM | Per-tool scopes, group-based server visibility |
| **Service account management** | IAM (M2M) | OAuth2 client credentials for automated agents and CI/CD |
| **Configuration drift detection** | System Config | Exportable config snapshots in 4 formats for diff comparison |
| **Operational visibility** | Audit + System Config | Full request tracing plus deployment parameter inventory |

---

## Validation

Before continuing, verify you've explored each Settings section:

- [ ] Opened the Settings page via the gear icon in the sidebar
- [ ] Viewed Audit logs and switched between the two log stream tabs
- [ ] Reviewed Federation sources and their sync status
- [ ] Examined the Virtual MCP configuration for the Dev Tools server
- [ ] Explored IAM — Groups, Users, and M2M tabs
- [ ] Noted the Notifications placeholder
- [ ] Searched and exported a configuration snapshot in System Config

::alert[**Settings Tour Complete!** You now have a full mental map of the MCP Gateway Registry — both the dashboard (what's registered) and the Settings (how it's governed). In the next module, you'll put these features to work with hands-on labs.]{type="success" header="Well Done!"}

:button[Continue to Lab 2: Fine-Grained Access Control]{href="/module-2"}
