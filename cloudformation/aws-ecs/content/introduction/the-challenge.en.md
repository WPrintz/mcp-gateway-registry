---
title: "The Challenge"
weight: 11
---

## How AI Tool Access Breaks Down at Scale

A single developer connecting Claude Code to an MCP server is straightforward. Ten teams doing it independently is a problem.

Here's what typically happens: an engineering team discovers MCP, connects their coding assistant to a few useful servers, and gets real productivity gains. Word spreads. Soon the finance team has their own MCP servers, the data science team has theirs, and operations has a few more. Each team manages their own connections, credentials, and configurations.

Within a few months, the organization has dozens of MCP servers, no inventory of what exists, no idea who's using what, and no way to enforce access policies. Security can't audit AI-initiated actions because there's no centralized log. A new hire spends their first week asking around to find out which tools are available and how to connect to them.

This is MCP sprawl, and it mirrors what happened with APIs, microservices, and SaaS tools before them. We can learn from these patterns to improve the experience for enterprise-scale agentic systems.

---

## Concrete Problems This Creates

**For platform teams:**
- Every MCP server has its own authentication scheme. Some use API keys, some use OAuth, some use nothing. There's no unified identity layer.
- When someone leaves the company, there's no single place to revoke their access to AI tools.
- You can't answer the question "which tools does the finance team have access to?" without asking the finance team.

**For developers and agent builders:**
- Configuring VS Code, Cursor, or Claude Code means manually setting up each MCP server connection with its own credentials. Change laptops? Do it again.
- Agents are limited to the tools they were configured with at build time. If a new MCP server gets deployed that would help with a task, the agent has no way to discover it.
- Building an agent that delegates to other agents requires hardcoding knowledge of those agents' endpoints and capabilities.

**For security and compliance:**
- Third-party MCP servers could contain malicious tool descriptions that manipulate agent behavior (prompt injection via tool metadata). There's no scanning or vetting process.
- No audit trail connects a specific user or agent identity to a specific tool invocation.
- There's no mechanism to restrict which tools a particular team or agent can access — it's all-or-nothing.

---

## What a Gateway Changes

The MCP Gateway and Registry sits between your agents and your MCP servers. Your existing servers don't change. Your agents connect to one endpoint instead of many.

What this makes possible:

| Capability | How It Works |
|------------|-------------|
| **One connection, many servers** | Agents and coding assistants connect to the gateway. The gateway routes to the right MCP server. |
| **Identity-aware access control** | Keycloak (or Entra ID, or Cognito) authenticates users and agents. Scopes define which servers, methods, and individual tools each group can access. |
| **Dynamic tool discovery** | Agents call `intelligent_tool_finder` with a natural language query. The registry returns matching tools from across all registered servers using semantic search. No hardcoding. |
| **Agent-to-agent discovery** | Agents register their capabilities. Other agents discover them by searching for skills, not by knowing endpoints. |
| **Security scanning** | When a server is registered, it's automatically scanned for known vulnerability patterns (YARA rules) and optionally analyzed by an LLM. Unsafe servers are disabled before any agent can reach them. |
| **Federation** | Import servers from Anthropic's public MCP registry or Workday's Agent System of Record. Apply your own access controls to federated tools. |
| **Observability** | Every authentication event, tool invocation, and discovery query is metered. Grafana dashboards show who's using what, how often, and whether it's working. |

::alert[The gateway doesn't replace your MCP servers — it sits in front of them, adding the governance layer that enterprises need before AI tool access can move from experimentation to production.]{type="info"}
