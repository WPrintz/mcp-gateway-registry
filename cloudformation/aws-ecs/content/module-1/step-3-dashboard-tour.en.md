---
title: "1.3 Explore the Dashboard"
weight: 23
---

The MCP Gateway Registry dashboard is your central hub for managing MCP servers, discovering AI agents, and monitoring tool usage. Let's explore the key sections.

## Main Dashboard Layout

:image[Dashboard Overview]{src="/static/img/module-1/1_3/Registry_overview.png" width=800}

The dashboard has three main areas:

**Header bar** — across the top you'll find the version number, theme toggle (sun/moon icon), and your username with a dropdown menu.  Click the 3-line icon in the upper left to hide or expose the left sidebar.

**Left sidebar** — shows your identity and access level (e.g., "Admin Access (keycloak)"), a **Get JWT Token** button, filter controls for services (All, Enabled, Disabled, With Issues), and summary statistics showing total counts.

**Main content area** — this is where you'll spend most of your time:
- **View tabs** at the top: *All*, *MCP Servers*, *Virtual MCP Servers*, *A2A Agents*, *Agent Skills*, *External Registries*
- **Search bar** with semantic search (press Enter) and local filtering (type to filter)
- **+ Register Server** and **Refresh Health** action buttons
- **MCP Servers** & **Virtual MCP Servers**
- **A2A Agents** 
- **Agent Skills**

---

## Key Features to Explore

### 1. Left Sidebar

The left sidebar provides quick access to filtering and identity features:

**Filter Services** — filter the main view by service status:
- **All Services** — everything registered (servers + agents)
- **Enabled** — only active services
- **Disabled** — services that have been toggled off
- **With Issues** — services with health check failures

Each filter shows a count badge so you can see at a glance how many services are in each state.

**Statistics** — at the bottom of the sidebar, summary counts for Total, Enabled, Disabled, and Issues.

**Get JWT Token** — click this button to generate a JWT access token for your current user. This is useful when you need to make direct API calls to the registry or connect AI coding assistants in later labs.

### 2. View Tabs

At the top of the main content area, you'll see six tabs that filter the dashboard by entity type. Each tab represents a different kind of resource the registry manages.

- **All** — Shows every registered resource across all types: MCP servers, virtual servers, A2A agents, and agent skills
- **MCP Servers** — Traditional MCP servers registered in the gateway. Each server runs behind an Nginx reverse proxy and exposes tools via the MCP protocol. Your workshop environment comes with three pre-registered servers (CurrentTime, AIRegistryTools, RealServerFakeTools).
- **Virtual MCP Servers** — Composite servers that aggregate tools from multiple backend MCP servers into a single virtual endpoint. Instead of connecting to each server individually, an AI agent can connect to one virtual server and access a curated set of tools from across the registry. Admins create virtual servers by selecting which tools to include from existing backends.
- **A2A Agents** — Agents that implement the Agent-to-Agent (A2A) protocol for inter-agent communication. Unlike MCP servers (which expose tools), A2A agents accept tasks from other agents and return results. Your workshop includes two pre-registered agents (Flight Booking, Travel Assistant).
- **Agent Skills** — Standalone capabilities defined by SKILL.md files. Skills describe what an agent can do in a structured format that other agents and systems can discover and invoke. Think of skills as a portable, self-describing contract for an agent's abilities.
- **External Registries** — Servers and agents discovered from federated peer registries. When federation is enabled, the registry can sync with external registries (such as Anthropic's public MCP registry) and display their servers alongside local ones. External resources can be imported into your local registry.

::alert[Try clicking each tab to see how the view changes. In the "All" view, each entity type appears in its own section with a distinct heading. The "External Registries" tab shows resources discovered from federated peers that can be imported into your local registry.]{type="info"}

### 3. Server Cards

Each MCP server is displayed as a card showing:

:image[Server Card Anatomy]{src="/static/img/module-1/1_3/mcp_card.png" width=400}

| Element | Description |
|---|---|
| **Name & Path** | Server name (e.g., "Current Time API") and its route (e.g., `/currenttime/`) |
| **Version** | Server version number (e.g., 1.26.0) |
| **Description** | What the server does |
| **Tags** | Categorization labels (e.g., #time, #registry, #demo) |
| **Ratings & Tools** | Star rating count and number of available tools |
| **Status** | Enabled/Disabled state and health status (Unknown, Healthy, Unhealthy) |
| **Action Icons** | Edit, settings, favorite, and enable/disable toggle |
| **Refresh** | Sync icon to refresh the server's tool list |

**Try this:** Click the **pencil icon** (✏️) in the upper-right of a server card to open the edit view. This is where you can modify the server's name, description, tags, and group visibility.

:image[Expanded Server Card with Tools]{src="/static/img/module-1/1_3/current_time_edit_server.png" width=800}

::alert[The workshop servers are pre-registered and **enabled**, except for the server named "Real Server Fake Tools". You'll notice that card shows "Disabled" with an "Unknown" health status.]{type="warning"}

### Enabling a Server

**Try this:** Enable the Real Server Fake Tools server, observe the health check and tools populate, then click the gear and tools icons on each to explore their configurations and tool descriptions.

1. Find the **enable/disable toggle** on the right side of a server card's footer
1. Click the toggle to enable the server — the status will change from "Disabled" to "Enabled"
1. Click the **Refresh Health** button at the top of the page (or the sync icon on the card) to check the server's health
1. Once healthy, click the **gear icon** (⚙) in the upper-right of the card to view the server's JSON configuration
1. Click the **tools icon** (🔧) to see the list of tool descriptions the server provides

:image[Expanded Server Card with Tools]{src="/static/img/module-1/1_3/realserverfaketools_tools.png" width=800}

:image[Expanded Server Card with Tools]{src="/static/img/module-1/1_3/realserverfaketools_config.png" width=800}

### YARA Security Scanning

When an MCP server, A2A agent, or Agent Skill is registered, the registry automatically runs a **YARA security scan** in the background. YARA is a pattern-based, signature-driven scanner that detects known threat signatures — SQL injection, command injection, hardcoded credentials, prompt injection attempts, data exfiltration patterns, and more. It runs in seconds, requires no API keys, and is the default security analyzer.

- If the scan result is **SAFE**, the component is enabled normally
- If the scan finds **critical or high severity** issues, the component is auto-disabled with a `security-pending` tag

You can see the scan result by clicking the **green shield icon** on a server card. This opens the YARA scan detail view showing each tool's analysis, matched rules, and overall risk assessment.

:image[YARA Scan Result for CurrentTime]{src="/static/img/module-1/1_3/current_time_YARA_scan_result.png" width=800}

**Try this:** Click the green shield icon on the CurrentTime server card to see its YARA scan results. Notice the per-tool breakdown and the overall security verdict.

::alert[YARA scanning is just one layer. The registry also supports Cisco AI Defense analyzers (LLM-based semantic analysis, VirusTotal, and more) for deeper inspection. These require additional API keys and are covered in advanced configuration.]{type="info"}

### Virtual MCP Servers

Virtual MCP Servers are one of the registry's most powerful features. Instead of requiring AI agents to connect to multiple individual MCP servers containing tools they may not need, a virtual server **aggregates tools from different backend servers into a single composite endpoint**. An agent connects to one URL and gets access to a curated set of tools drawn from across the registry.  It's simpler to configure and avoids wasting context memory.

Here's how it works:

```
┌──────────────────────────────────┐
│     Virtual Server: Dev Tools    │
│        /virtual/dev-tools        │
├──────────────────────────────────┤
│  current_time_by_timezone        │──▶  /currenttime/ (backend)
│  intelligent_tool_finder         │──▶  /airegistry-tools/ (backend)
└──────────────────────────────────┘
```

Each **tool mapping** selects a specific tool from a backend MCP server. The virtual server resolves these mappings at request time, routing each tool call to the correct backend transparently. Administrators can:

- **Cherry-pick tools** from different servers into purpose-built toolkits
- **Alias tools** to rename them and avoid naming conflicts across backends
- **Pin versions** to lock a tool mapping to a specific backend version
- **Override scopes** to restrict individual tools to specific user groups

Virtual servers don't run their own backend process. They are a routing and composition layer managed entirely by the registry. When an AI agent calls a tool on a virtual server, the registry looks up the tool mapping, forwards the request to the correct backend MCP server, and returns the result.

Click the **Virtual MCP Servers** view tab to see the pre-registered "Dev Tools" virtual server, or scroll down to the "Virtual MCP Servers" section in the **All** view. Try clicking the **pencil icon** to see the tool mappings and which backends each tool is sourced from.

:image[Virtual MCP Server card on the dashboard]{src="/static/img/module-1/1_3/virtual_server_card.png" width=800}

::alert[Virtual servers are explored hands-on in later modules. For now, just notice how they appear on the dashboard alongside regular MCP servers.]{type="info"}

### 4. Pre-Registered MCP Servers

Your workshop environment comes with these pre-registered servers:

::::tabs

:::tab{label="CurrentTime"}
**Current Time API**
- **Path**: `/currenttime/`
- **Purpose**: A simple API that returns the current server time in various formats
- **Tools** (1):
  - `current_time_by_timezone` — Get the current time in a specified timezone

A simple utility server, perfect for testing agent connectivity.
:::

:::tab{label="AIRegistryTools"}
**AI Registry Tools**
- **Path**: `/airegistry-tools/`
- **Purpose**: Provides tools to interact with the MCP Gateway Registry API
- **Tools** (5):
  - `intelligent_tool_finder` — Semantic search for tools across all servers
  - `list_services` / `register_service` / `remove_service` — Server management
  - `toggle_service` — Server operations

The `intelligent_tool_finder` is particularly powerful — it lets AI agents discover tools using natural language queries across all registered servers.
:::

:::tab{label="RealServerFakeTools"}
**Real Server Fake Tools**
- **Path**: `/realserverfaketools/`
- **Purpose**: A collection of fake tools with interesting names for testing
- **Tools** (6):
  - `quantum_flux_analyzer`, `neural_pattern_synthesizer`, `hyper_dimensional_mapper`
  - `temporal_anomaly_detector`, `user_profile_analyzer`, `synthetic_data_generator`

These return mock data — useful for testing agent workflows and access control without real external dependencies.
:::

::::


### 5. Pre-Registered Agent Skills

Your workshop includes two pre-registered **Agent Skills** sourced from [Anthropic's public skills repository](https://github.com/anthropics/skills). Agent Skills are standalone capabilities defined by SKILL.md files — a structured format that describes what an agent can do, making it discoverable by other agents and systems in the registry.

Click the **Agent Skills** view tab to see them, or scroll to the "Agent Skills" section in the **All** view.

**Frontend Design** (`/skills/frontend-design`)
- **Purpose**: Create distinctive, production-grade frontend interfaces with high design quality
- **Source**: [SKILL.md](https://raw.githubusercontent.com/anthropics/skills/refs/heads/main/skills/frontend-design/SKILL.md)

**Canvas Design** (`/skills/canvas-design`)
- **Purpose**: Create beautiful visual art in .png and .pdf documents using design philosophy
- **Source**: [SKILL.md](https://raw.githubusercontent.com/anthropics/skills/refs/heads/main/skills/canvas-design/SKILL.md)

::alert[Agent Skills differ from MCP servers and A2A agents in that they don't require a running backend service. Each skill is defined entirely by its SKILL.md file, which specifies the skill's name, description, and instructions. The registry parses and indexes these files so agents can discover relevant skills through search.]{type="info"}

### 6. External Registries

Click the **External Registries** tab to see servers and agents discovered from federated peer registries.

:image[External Registries Tab]{src="/static/img/module-1/1_3/external_registry.png" width=800}

When federation is enabled, the MCP Gateway Registry can sync with external registries — such as Anthropic's public MCP server registry — and display their servers alongside your local ones. The External Registries tab shows these discovered resources in the same card layout you've already seen, but with a few key differences:

- **Source badges** — each card shows `ANTHROPIC` and `LOB_REGISTRY` tags indicating which peer registry the server was discovered from and its original source type
- **Health status** — the registry periodically checks whether external servers are reachable, showing Healthy/Unhealthy status just like local servers
- **Ratings and tools** — external servers display their community ratings and tool counts as reported by the peer registry
- **Enable/Disable toggle** — you can enable or disable visibility of individual external servers without affecting the peer registry

External servers are read-only — you can browse their descriptions, tags, and tool lists, but you cannot edit their configuration. If you find an external server useful, you can import it into your local registry as a fully managed MCP server.

::alert[Federation is not pre-configured in this workshop environment, so your External Registries tab will be empty. The screenshot above shows what it looks like when a registry is federated with an external peer — in this case, Anthropic's public MCP server registry. Federation configuration is covered in the Settings tour next.]{type="info"}

### 7. Search Bar

The search bar at the top supports two modes:

- **Keyword Search** (instant): Filters visible cards as you type
- **Semantic Search** (press Enter): Uses AI embeddings to find tools by meaning

:image[Search Bar]{src="/static/img/module-1/1_3/Registry_search_highlight.png" width=800}

**Try this:** Type "what time is it" and press Enter. The semantic search will find the CurrentTime server even though those exact words aren't in its description.

:image[Semantic Search Results]{src="/static/img/module-1/1_3/search_what_time.png" width=800}

Notice that each result shows a **match percentage** — this is the semantic similarity score between your query and the server or tool description. In this example, "Current Time API" shows **100% match** while less relevant servers score lower. Results are split into two sections: **Matching Servers** ranked by overall relevance, and **Matching Tools** showing individual tools that best match your query.

---

## Quick Exploration Tasks

Before moving to the next module, try these quick tasks:

::alert[These are self-guided exploration tasks. There's no "right answer" - just get familiar with the interface.]{type="info"}

1. **Toggle a server**: Find the CurrentTime server and click its enable/disable toggle. Notice how the status changes.

2. **View server tools**: Click on the AI Registry Tools server card to expand it. Look at the `intelligent_tool_finder` tool - this is what AI agents use to discover capabilities.

3. **Try the filters**: Click "Agents" to see the pre-registered A2A agents (Travel Assistant, Flight Booking).

4. **Search for tools**: Type "book a flight" in the search bar and press Enter. See which agents and servers match.

5. **Check the External view**: Click "External" to see servers available from federated registries (Anthropic's public MCP registry).

---

## What's Happening Behind the Scenes

When you interact with the dashboard, here's what's happening:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────▶│   Registry  │────▶│  Keycloak   │
│  (React UI) │     │  (FastAPI)  │     │   (OIDC)    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ MCP Servers │
                    │ (via Nginx) │
                    └─────────────┘
```

1. **React Frontend** sends API requests to the Registry backend
1. **Registry** validates your session cookie (issued by Keycloak)
1. **Registry** checks your group memberships to filter visible servers
1. **Nginx** proxies requests to actual MCP servers when you invoke tools

---

## Validation

Before continuing, verify you can:

- [ ] See the main dashboard with server cards
- [ ] Switch between All, Servers, Agents, and External views
- [ ] Click on a server card to see its tools
- [ ] Use the search bar (both keyword and semantic search)
- [ ] Toggle the theme between light and dark mode

::alert[**Dashboard Tour Complete!** You've explored the main dashboard — server cards, view tabs, search, and pre-registered resources. Next, you'll tour the **Settings** page to see how the platform is governed: audit logging, federation, IAM, and more.]{type="success" header="Well Done!"}

:button[Next: Explore the Settings]{href="/module-1/step-4-settings-tour"}
