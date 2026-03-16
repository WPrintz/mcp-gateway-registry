---
title: "5.4 View Skill Content and Metadata"
weight: 64
---

Before downloading a skill, you might want to inspect its content and metadata from the command line.

## Step 1: View Skill Content

View the full SKILL.md for the `mcp-builder` skill:

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

This is what the AI assistant reads when you invoke the skill.

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

The JSON includes the registration fields you set in 5.2, plus system fields like `path`, `is_enabled`, and `health_status`.

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

Each skill has different instructions, but the Registry treats them all the same way.

---

## Lab 5 Summary

| Step | What You Learned |
|------|------------------|
| **5.1** | How to browse the Skills catalog and view SKILL.md content in the Registry UI |
| **5.2** | How visibility levels work for internal vs public skills, and how to register and health-check skills via CLI |
| **5.3** | How to download a skill from the Registry and invoke it in Claude Code |
| **5.4** | How to inspect skill content and metadata via the CLI |

::alert[**Lab 5 Complete!** Your registry now has 5 skills alongside the MCP servers from Labs 1-4.]{type="success" header="Well Done!"}

:button[Continue to Summary]{href="/summary"}
