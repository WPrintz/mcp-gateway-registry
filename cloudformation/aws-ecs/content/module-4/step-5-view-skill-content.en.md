---
title: "4.5 View Skill Content and Metadata"
weight: 55
---

Inspect the full SKILL.md content and metadata for registered skills using the CLI. This is useful for reviewing what instructions a skill provides before downloading it, or for auditing registered skills across the organization.

## Step 1: View Skill Content

View the complete SKILL.md instructions that guide the AI assistant:

:::code{language=bash showCopyAction=true}
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-content --path mcp-builder
:::

You should see the full text of the SKILL.md file:

:::code{language=text showCopyAction=false}
# MCP Builder Skill

This skill helps you build MCP (Model Context Protocol) servers...

## Required Tools
- Python 3.10+
- uv package manager

## Workflow
1. Define the server's tools and their schemas
2. Implement tool handlers
3. Set up transport (stdio or HTTP)
...
:::

:image[Terminal showing SKILL.md content output for mcp-builder]{src="/static/img/module-4/4_5/skill-content-output.png" width=800}

This is the same content the AI assistant reads when you invoke the skill. Review it to understand what workflows and behaviors the skill defines — including required tools, step-by-step processes, and best practices.

---

## Step 2: View Skill Metadata

View the skill's registration metadata (name, tags, health status, visibility):

:::code{language=bash showCopyAction=true}
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-get --path mcp-builder
:::

You should see output like:

:::code{language=json showCopyAction=false}
{
  "name": "mcp-builder",
  "url": "https://github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md",
  "description": "Build MCP servers and tools for AI assistant integrations",
  "tags": ["mcp", "coding", "development", "servers"],
  "visibility": "public",
  "health": "healthy"
}
:::

:image[Terminal showing skill metadata output]{src="/static/img/module-4/4_5/skill-metadata-output.png" width=800}

The metadata shows:

| Field | Description | Example |
|-------|-------------|---------|
| **name** | Skill identifier used in slash commands and API calls | `mcp-builder` |
| **url** | Source SKILL.md location (Git repository URL) | `https://github.com/anthropics/skills/...` |
| **description** | Human-readable summary for search and display | "Build MCP servers..." |
| **tags** | Categorization for search and filtering | `mcp`, `coding`, `development` |
| **visibility** | Access level: `public`, `group`, or `private` | `public` |
| **health** | Whether the source URL is reachable | `healthy` |

---

## Step 3: Compare Skills

Try viewing content for different skills to see how they vary:

:::code{language=bash showCopyAction=true}
# View the pdf skill content
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-content --path pdf
:::

:::code{language=bash showCopyAction=true}
# View the xlsx skill metadata
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-get --path xlsx
:::

Each skill has a different structure and set of instructions tailored to its domain. The Registry treats them uniformly — same registration, discovery, health monitoring, and access control — regardless of content.

---

## What You've Accomplished

You've completed the full skill lifecycle:

| Phase | What Happened |
|-------|---------------|
| **Browse** | Explored the Skills catalog in the Registry UI |
| **Register (internal)** | Created a team-scoped skill with `group` visibility |
| **Register (public)** | Imported four official Anthropic skills with `public` visibility |
| **Health check** | Verified the SKILL.md source URLs are accessible |
| **Download** | Fetched skill content via the Registry API |
| **Invoke** | Used the skill in Claude Code via slash command |
| **Inspect** | Viewed full SKILL.md content and registration metadata via CLI |

Your registry now has **5 registered skills** — 1 internal and 4 public — alongside the MCP servers from Labs 1-3.

---

## Lab 4 Summary

| Step | What You Learned |
|------|------------------|
| **4.1** | How to browse and search the Skills catalog in the Registry UI |
| **4.2** | How to register an internal skill with `group` visibility for team-only access |
| **4.3** | How to import public skills from external repositories and verify health |
| **4.4** | How to download a skill from the Registry and invoke it in Claude Code |
| **4.5** | How to inspect skill content and metadata via the CLI |

### Key Takeaways

1. **Skills are behavioral guidance**, not executable tools — they provide instructions that shape how an AI assistant works
2. **The Registry governs both skills and MCP servers** under the same discovery, health monitoring, and access control framework
3. **Visibility levels** (`public`, `group`, `private`) control who can discover and download skills — the same group-based model from Lab 3
4. **Health checks verify source accessibility** — the Registry monitors whether SKILL.md files are reachable at their Git URLs
5. **Skills complement MCP servers** — tools provide *what* an AI can do; skills provide *how* it should do it

::alert[**Lab 4 Complete!** You've discovered, registered, verified, downloaded, and invoked Agent Skills through the MCP Gateway Registry. Skills and MCP servers together give enterprises a complete governance framework for AI assistant capabilities — tools *and* behaviors.]{type="success" header="Well Done!"}

:button[Continue to Summary]{href="/summary"}
