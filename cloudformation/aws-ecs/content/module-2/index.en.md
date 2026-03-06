---
title: "Lab 2: Registry Discovery & Server Registration"
weight: 30
---

In this lab, you'll explore how the MCP Gateway Registry helps you discover tools and agents using semantic search, then register a real external MCP server — the **Cloudflare Documentation** server — and verify it works end-to-end through the MCP protocol.

**Estimated Time:** 30 minutes

## What You'll Learn

- How keyword filtering differs from AI-powered semantic search
- How different users see different search results based on their permissions
- How to register an external MCP server through the Registry UI
- How to enable, health-check, and test a newly registered server via the MCP protocol

## Prerequisites

- Completed Lab 1 (familiar with the Registry UI and login process)
- Logged into the MCP Gateway Registry as `admin`

::alert[Make sure you're logged in as `admin` before starting this lab. Semantic search and server registration require authentication.]{type="warning"}

---

## Why Discovery Matters

In a large enterprise with hundreds of MCP servers, finding the right tool becomes the first challenge:

| Challenge | Traditional Approach | Registry Approach |
|-----------|---------------------|-------------------|
| **Different naming conventions** | Must know exact name | Semantic search finds by meaning |
| **New team members** | Trial and error | Natural language queries |
| **Tool proliferation** | Overwhelming lists | Relevant results ranked by similarity |
| **External tools** | Manual configuration | Register once, discover everywhere |

The MCP Gateway Registry addresses discovery with two complementary mechanisms: instant keyword filtering for when you know what you're looking for, and AI-powered semantic search for when you know what you *need* but not which tool provides it.

---

## The Journey

This lab follows a natural progression:

1. **Understand search** — Learn keyword filtering vs semantic search, access control implications, and the programmatic discovery API
2. **Register a server** — Add the Cloudflare Documentation MCP server to your registry
3. **Verify it works** — Enable the server, run health checks, and test the MCP protocol

By the end, you'll have a fourth MCP server in your registry — one you registered yourself — ready for the access control exercises in Lab 3.

## Learn More

- [Dynamic Tool Discovery](https://agentic-community.github.io/mcp-gateway-registry/dynamic-tool-discovery/) — Deep dive into the `intelligent_tool_finder` and semantic search architecture
- [Embeddings Configuration](https://agentic-community.github.io/mcp-gateway-registry/embeddings/) — Configure embedding providers (Sentence Transformers, OpenAI, Amazon Bedrock)

## Steps

::children
