---
title: "Deep Dive: How Embeddings Power Search"
weight: 39
---

::alert[This is an optional reference page. You don't need to read it to continue the workshop — it's here for participants who want to understand the technical details behind semantic search.]{type="info"}

## What Are Embeddings?

An embedding is a fixed-length vector (array of numbers) that represents the semantic meaning of a piece of text. Texts with similar meanings produce vectors that are close together in the embedding space.

For example, these phrases produce similar vectors:
- "get the current time" ≈ "what time is it" ≈ "check the clock"
- "book a flight" ≈ "airline reservation" ≈ "travel booking"

And these produce distant vectors:
- "get the current time" ≠ "book a flight"

The MCP Gateway uses embeddings to match your natural language search queries against the descriptions of registered servers, tools, and agents.

---

## The Embedding Pipeline

### At Registration Time

When a server or agent is registered, the gateway:

1. **Concatenates text fields** — server name, description, tool names, tool descriptions, tags
2. **Sends text to the embedding model** — the model returns a vector (typically 384 or 768 dimensions)
3. **Stores the vector** in DocumentDB alongside the registration record

### At Search Time

When you press Enter in the search bar:

1. **Your query is embedded** using the same model
2. **Cosine similarity** is computed between your query vector and every stored vector
3. **Results are ranked** by similarity score (1.0 = identical meaning, 0.0 = unrelated)
4. **Access control filters** remove results the user isn't authorized to see

```
Registration:
  "Current Time API - Get current time by timezone"
    → Model → [0.23, 0.87, 0.12, -0.45, ...]  (stored in DocumentDB)

Search:
  "what time is it in Tokyo?"
    → Model → [0.21, 0.85, 0.14, -0.42, ...]  (computed at query time)

Cosine similarity: 0.97  →  Strong match!
```

---

## Embedding Model Configuration

The MCP Gateway supports multiple embedding providers:

| Provider | Model | Dimensions | Latency | Cost |
|----------|-------|------------|---------|------|
| **Sentence Transformers** (default) | `all-MiniLM-L6-v2` | 384 | ~50ms | Free (runs locally) |
| **Amazon Bedrock** | Titan Embeddings | 1024 | ~200ms | Per-token pricing |
| **OpenAI** | `text-embedding-3-small` | 1536 | ~150ms | Per-token pricing |

The workshop environment uses **Sentence Transformers** — the model runs inside the Registry container, so there's no external API call and no additional cost.

::alert[The embedding model is configured via the `EMBEDDING_PROVIDER` environment variable in the Registry service. Changing providers requires re-embedding all existing registrations.]{type="info"}

---

## Cosine Similarity

Cosine similarity measures the angle between two vectors, ignoring their magnitude. It returns a value between -1 and 1:

| Score | Interpretation |
|-------|---------------|
| 0.90 – 1.00 | Very strong match (nearly identical meaning) |
| 0.70 – 0.89 | Good match (related concepts) |
| 0.50 – 0.69 | Weak match (loosely related) |
| Below 0.50 | Poor match (likely unrelated) |

The gateway uses a configurable threshold to filter out weak matches. Results below the threshold don't appear in search results.

---

## Why Embeddings Beat Keywords

Consider searching for "schedule a meeting":

| Approach | Matches "Calendar Service" | Matches "Meeting Scheduler" | Matches "Time Slot Finder" |
|----------|---------------------------|-----------------------------|-----------------------------|
| **Keyword** | ❌ No keyword overlap | ✅ "meeting" matches | ❌ No keyword overlap |
| **Semantic** | ✅ Calendars relate to scheduling | ✅ Direct match | ✅ Time slots relate to scheduling |

Embeddings capture relationships between concepts that keyword matching misses entirely. This is especially valuable in large registries where different teams use different terminology for similar capabilities.

---

## The intelligent_tool_finder Connection

The `intelligent_tool_finder` tool on the AI Registry Tools server uses the same embedding pipeline. When an AI agent calls it:

1. The agent sends a natural language query (e.g., "get weather for a city")
2. The gateway embeds the query and runs cosine similarity against all tool embeddings
3. Results are filtered by the agent's access control scope
4. Matching tools are returned with their server, description, and similarity score

This means the search bar in the UI and the `intelligent_tool_finder` MCP tool share the same underlying engine — one is for humans, the other is for AI agents.

---

## Further Reading

- [Embeddings Configuration Guide](https://agentic-community.github.io/mcp-gateway-registry/embeddings/) — How to configure different embedding providers
- [Dynamic Tool Discovery](https://agentic-community.github.io/mcp-gateway-registry/dynamic-tool-discovery/) — Architecture of the `intelligent_tool_finder`
- [Sentence Transformers](https://www.sbert.net/) — The default embedding model library
