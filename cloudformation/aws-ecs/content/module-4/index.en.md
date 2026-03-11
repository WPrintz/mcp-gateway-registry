---
title: "Lab 4: Skills Registry"
weight: 50
---

In this lab, you'll explore how the MCP Gateway Registry manages **Agent Skills** — reusable instruction sets (SKILL.md files) that enhance AI coding assistants with specialized workflows. Unlike MCP servers that provide tools, skills provide behavioral guidance and context.

**Estimated Time:** 20 minutes

## What You'll Learn

- How to browse and search the Skills catalog in the Registry UI
- How to register internal and public skills via the CLI
- How to verify skill health (accessibility of the SKILL.md source)
- How to download and use a skill in Claude Code
- How to inspect skill content and metadata

## Prerequisites

- Completed Lab 1 (familiar with the Registry UI and login process)
- Completed Lab 2 (familiar with server registration and CLI token workflow)
- Logged into the MCP Gateway Registry as `admin`
- A terminal with access to the workshop environment (AWS CloudShell or local)

::alert[Skills complement MCP servers. MCP servers expose **tools** (functions an AI can call). Skills expose **instructions** (workflows and context that guide AI behavior). The Registry governs both.]{type="info"}

---

## What Are Agent Skills?

Agent Skills are SKILL.md files hosted in Git repositories. Each file contains structured instructions that an AI coding assistant follows when the skill is invoked. For example:

| Skill | What It Does | Source |
|-------|-------------|--------|
| **pdf** | Guides the AI through creating and manipulating PDF documents | `anthropics/skills` repo |
| **xlsx** | Guides the AI through creating Excel spreadsheets | `anthropics/skills` repo |
| **mcp-builder** | Guides the AI through building MCP servers | `anthropics/skills` repo |
| **internal-code-review** | Your organization's code review workflow | Internal GitHub repo |

The Registry provides centralized discovery, health monitoring, and governance for skills — the same way it does for MCP servers.

---

## MCP Servers vs Skills

| Aspect | MCP Servers | Agent Skills |
|--------|------------|--------------|
| **What they provide** | Executable tools (functions) | Behavioral instructions (workflows) |
| **How they work** | AI calls a tool, gets a result | AI reads instructions, applies them to your request |
| **Transport** | MCP protocol over HTTP/SSE | SKILL.md file fetched from Git URL |
| **Health check** | MCP `initialize` request to upstream server | HTTP GET to verify SKILL.md URL is accessible |
| **Access control** | Group-based scopes (Lab 3) | Visibility levels: `public`, `group`, `private` |
| **Registration** | UI form or CLI | CLI only |

---

## The Journey

This lab follows five activities:

1. **Browse the catalog** — Explore registered skills in the UI
2. **Register an internal skill** — Add a team-scoped skill with group visibility
3. **Register public skills** — Import official Anthropic skills and verify their health
4. **Use a skill locally** — Download a skill and invoke it in Claude Code
5. **Inspect skill content** — View the full SKILL.md instructions and metadata

## Steps

::children
