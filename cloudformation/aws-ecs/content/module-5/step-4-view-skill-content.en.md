---
title: "5.4 View Skill Content and Metadata"
weight: 64
---

Inspect the full SKILL.md content and metadata for registered skills using the CLI. This is useful for reviewing what instructions a skill provides before downloading it, or for auditing registered skills across the organization.

## Step 1: View Skill Content

View the complete SKILL.md instructions that guide the AI assistant:

:::code{language=bash showCopyAction=true}
curl -s "$REGISTRY_URL/api/skills/mcp-builder/content" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq -r '.content'
:::

You should see the full text of the SKILL.md file:

:::code{language=text showCopyAction=false}
name: mcp-builder
description: Guide for creating high-quality MCP (Model Context Protocol)
  servers that enable LLMs to interact with external services through
  well-designed tools...
license: Complete terms in LICENSE.txt

# MCP Server Development Guide

## Overview

Create MCP (Model Context Protocol) servers that enable LLMs to interact
with external services through well-designed tools...

# Process

## High-Level Workflow

Creating a high-quality MCP server involves four main phases:

### Phase 1: Deep Research and Planning
...
:::

This is the same content the AI assistant reads when you invoke the skill. Review it to understand what workflows and behaviors the skill defines — including required tools, step-by-step processes, and best practices.

---

## Step 2: View Skill Metadata

View the skill's registration metadata (name, tags, health status, visibility):

:::code{language=bash showCopyAction=true}
curl -s "$REGISTRY_URL/api/skills/mcp-builder" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq .
:::

You should see output like:

:::code{language=json showCopyAction=false}
{
  "path": "/skills/mcp-builder",
  "name": "mcp-builder",
  "description": "Build MCP servers and tools for AI assistant integrations",
  "skill_md_url": "https://github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md",
  "skill_md_raw_url": "https://raw.githubusercontent.com/anthropics/skills/.../SKILL.md",
  "tags": ["mcp", "coding", "development", "servers"],
  "visibility": "public",
  "owner": "admin",
  "is_enabled": true,
  "health_status": "unknown",
  "num_stars": 0.0,
  "created_at": "2026-03-11T22:43:08.653003Z",
  ...
}
:::

The metadata shows:

| Field | Description | Example |
|-------|-------------|---------|
| **name** | Skill identifier used in slash commands and API calls | `mcp-builder` |
| **path** | URL-safe path used in API endpoints | `mcp-builder` |
| **skill_md_url** | Source SKILL.md location (Git repository URL) | `https://github.com/anthropics/skills/...` |
| **description** | Human-readable summary for search and display | "Build MCP servers..." |
| **tags** | Categorization for search and filtering | `mcp`, `coding`, `development` |
| **visibility** | Access level: `public`, `group`, or `private` | `public` |
| **is_enabled** | Whether the skill is active in the registry | `true` |

---

## Step 3: Compare Skills

Try viewing content for different skills to see how they vary:

:::code{language=bash showCopyAction=true}
# View the pdf skill content
curl -s "$REGISTRY_URL/api/skills/pdf/content" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq -r '.content'
:::

:::code{language=bash showCopyAction=true}
# View the xlsx skill metadata
curl -s "$REGISTRY_URL/api/skills/xlsx" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq .
:::

Each skill has a different structure and set of instructions tailored to its domain. The Registry treats them uniformly — same registration, discovery, health monitoring, and access control — regardless of content.

---

## What You've Accomplished

You've completed the full skill lifecycle:

| Phase | What Happened |
|-------|---------------|
| **Browse** | Explored the Skills catalog in the Registry UI |
| **Register** | Learned about internal team skills, then registered three public Anthropic skills |
| **Health check** | Verified the SKILL.md source URLs are accessible |
| **Download** | Fetched skill content via the Registry API |
| **Invoke** | Used the skill in Claude Code via slash command |
| **Inspect** | Viewed full SKILL.md content and registration metadata via CLI |

Your registry now has **5 registered skills** — 2 pre-deployed and 3 you registered — alongside the MCP servers from Labs 1-4.

---

## Lab 5 Summary

| Step | What You Learned |
|------|------------------|
| **5.1** | How to browse the Skills catalog and view SKILL.md content in the Registry UI |
| **5.2** | How visibility levels work for internal vs public skills, and how to register and health-check skills via CLI |
| **5.3** | How to download a skill from the Registry and invoke it in Claude Code |
| **5.4** | How to inspect skill content and metadata via the CLI |

### Key Takeaways

1. **Skills are behavioral guidance**, not executable tools — they provide instructions that shape how an AI assistant works
2. **The Registry governs both skills and MCP servers** under the same discovery, health monitoring, and access control framework
3. **Visibility levels** (`public`, `group`, `private`) control who can discover and download skills — the same group-based model from Lab 3
4. **Health checks verify source accessibility** — the Registry monitors whether SKILL.md files are reachable at their Git URLs
5. **Skills complement MCP servers** — tools provide *what* an AI can do; skills provide *how* it should do it

::alert[**Lab 5 Complete!** You've discovered, registered, verified, downloaded, and invoked Agent Skills through the MCP Gateway Registry. Skills and MCP servers together give enterprises a complete governance framework for AI assistant capabilities — tools *and* behaviors.]{type="success" header="Well Done!"}

:button[Continue to Summary]{href="/summary"}
