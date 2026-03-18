---
title: "Lab 4: AI Coding Assistant Integration"
weight: 50
---

Connect AI coding assistants to MCP servers through two approaches: a direct connection to a single server, then a virtual server that routes to multiple backends through one endpoint.

**Estimated Time:** 45 minutes

## What You'll Learn

- How to launch the cloud-based Code Editor and verify pre-installed AI tools
- How to connect Claude Code directly to a single MCP server using the Registry UI
- How to connect Claude Code and Kiro CLI to a virtual server for multi-backend access
- How access control rules from Lab 3 apply to AI assistant connections

## Prerequisites

- Completed Lab 1 (CloudFormation outputs, admin password)
- Completed Lab 2 (Cloudflare Documentation server registered and enabled)
- Completed Lab 3 (familiar with access control and scope-based permissions)

::alert[This lab uses the **Code Editor** — a browser-based VS Code environment. No local software installation is required.]{type="info"}

---

## Two Approaches to MCP Integration

| | Direct Connection | Virtual Server |
|---|---|---|
| **Setup** | One config entry per server | One config entry, multiple backends |
| **Adding servers** | New config entry + new token per server | Add a backend mapping, same endpoint |
| **Access control** | Managed per connection | Enforced centrally by the virtual server |

---

## The Journey

1. **Launch the IDE** — Open the Code Editor, verify Claude Code and Kiro CLI
2. **Direct Connection** — Connect Claude Code to a single MCP server
3. **Virtual Server** — Connect Claude Code and Kiro CLI to a virtual server that routes to multiple backends
4. **Compare and Reflect** — Side-by-side comparison, access control test with a restricted user

## Steps

::children
