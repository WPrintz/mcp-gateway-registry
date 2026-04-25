---
title: "Workshop Architecture"
weight: 13
---

## What's Deployed in Your Environment

Your workshop environment includes a fully functional MCP Gateway and Registry running on AWS. All infrastructure is pre-deployed—you'll focus on using and exploring the platform.

---

## Core Components

### MCP Gateway Registry

The central hub for managing MCP servers and A2A agents.

| Component | Description |
|---|---|
| **Registry UI** | React-based dashboard for browsing servers, agents, and search |
| **Registry API** | FastAPI backend handling registration, discovery, and routing |
| **Nginx Proxy** | Routes requests to appropriate MCP servers |
| **Embeddings Service** | Powers semantic search using vector embeddings |

### Identity & Access

| Component | Description |
|---|---|
| **Keycloak** | Identity provider for user authentication and group management |
| **OAuth2/OIDC** | Standard protocols for human and machine authentication |
| **Group-based Access** | Users and agents see only the tools they're authorized for |

### Pre-Registered MCP Servers

| Server | Path | Tools | Purpose |
|---|---|---|---|
| **Current Time API** | `/currenttime/` | 1 | A simple API that returns the current server time in various formats |
| **AI Registry Tools** | `/airegistry-tools/` | 5 | Provides tools to interact with the MCP Gateway Registry API |
| **Real Server Fake Tools** | `/realserverfaketools/` | 6 | A collection of fake tools with interesting names for testing |

### Pre-Registered A2A Agents

| Agent | Skills | Visibility | Purpose |
|---|---|---|---|
| **Flight Booking Agent** | 5 | Public | Books flights and manages reservations |
| **Travel Assistant Agent** | 4 | Public | Flight search and trip planning |

---

## AWS Infrastructure

The workshop runs on Amazon ECS with the following architecture:

:image[Workshop Architecture]{src="/static/img/introduction/workshop-architecture.drawio.png" width=800}

---

## Pre-Configured Users

The workshop includes several user accounts for testing access control. Each user belongs to different Keycloak groups that determine which servers and agents they can see.

| Username | Password | Role | Servers Visible |
|---|---|---|---|
| `admin` | (from Secrets Manager) | Platform Admin | All servers, all agents |
| `testuser` | `testpass` | Developer/Operator | All servers, all agents (read/execute) |
| `lob1-user` | `lob1pass` | LOB1 — Line of Business 1 | `currenttime`, `airegistry-tools` |
| `lob2-user` | `lob2pass` | LOB2 — Line of Business 2 | `realserverfaketools`, `airegistry-tools` |

::alert[The LOB users demonstrate multi-tenant access control. LOB1 and LOB2 share access to the `airegistry-tools` server but see different MCP servers otherwise. You'll explore this in detail in Lab 2.]{type="info"}

---

## Key URLs

You'll find these URLs in the CloudFormation stack outputs (stack name: **main-stack**):

| Resource | Output Key |
|---|---|
| Registry UI | `MCPGatewayUrl` |
| Keycloak Admin Console | `KeycloakUrl` |
| Admin Password | `MCPGatewayAdminPassword` (link to Secrets Manager) |
| Keycloak Admin Password | `KeycloakAdminPassword` (link to SSM Parameter Store) |
| Grafana Dashboard | `GrafanaUrl` |

::alert[In Lab 1, you'll retrieve these URLs from CloudFormation and use them to access the workshop environment.]{type="info"}

---

## Learn More

- [Installation Guide](https://agentic-community.github.io/mcp-gateway-registry/installation/) - Deploy your own MCP Gateway
- [Configuration Reference](https://agentic-community.github.io/mcp-gateway-registry/configuration/) - Environment variables and settings
- [Production Deployment](https://agentic-community.github.io/mcp-gateway-registry/installation/) - AWS ECS and EKS deployment patterns

:button[Start the Workshop]{href="/module-1"}
