---
title: "2.1 Keyword vs Semantic Search"
weight: 31
---

The MCP Gateway Registry provides two search modes: instant keyword filtering and AI-powered semantic search. Understanding the difference helps you find tools more effectively.

## Keyword Filtering (Instant)

As you type in the search bar, the dashboard instantly filters visible cards based on exact text matches.

**How it works:**
- Matches against server names, descriptions, and tags
- Case-insensitive
- Filters happen client-side (instant, no network request)
- Shows only cards containing your search text

**Try this:**

1. Make sure you're logged in as `admin`
2. In the search bar, type `time`
3. Notice the cards filter instantly as you type — only the **Current Time API** card remains visible
4. Clear the search bar — all cards reappear

Now try a keyword that appears in tags:

1. Type `demo`
2. The **Real Server Fake Tools** card remains — it has `demo` in its tags
3. Clear the search bar

::alert[Keyword filtering only works on text that literally appears in the server name, description, or tags. If you search for "clock" or "what time is it", nothing matches — even though the Current Time API is exactly what you need.]{type="info"}

---

## Semantic Search (Press Enter)

When you press **Enter**, the gateway performs a semantic search using AI embeddings. 

**How it works:**
- Your query is converted to a vector embedding by an AI model
- The gateway compares it against pre-computed embeddings of all tools and agents
- Results are ranked by semantic similarity (cosine distance)
- Works across servers, tools, and agents simultaneously

**Try this:**

1. Clear the search bar
2. Type `add a server`
3. Press **Enter**
4. The results show the **AI Registry Tools** server and three of its tools: `register_service`, `toggle_service`, and `list_services` — even though the words "add" and "server" don't appear in any of those names

:image[Semantic search results for add a server]{src="/static/img/module-2/2_1/semantic-search-add-server.png" width=800}


The embedding model understands that "add a server" semantically relates to registering, toggling, and listing services. Notice how semantic search returns both server-level and tool-level matches.

---

## Comparison

| Aspect | Keyword Filtering | Semantic Search |
|--------|-------------------|-----------------|
| **Trigger** | As you type | Press Enter |
| **Matching** | Exact text match | Meaning-based |
| **Speed** | Instant (client-side) | ~1-2 seconds (server-side) |
| **Scope** | Visible card text only | All registered resources |
| **Best for** | Know the name | Know what you need |

::alert[Use keyword filtering when you know the server name. Use semantic search when you know what capability you need but not which tool provides it.]{type="info"}

---

## How Semantic Search Works Under the Hood

When a server or agent is registered, the gateway:

1. **Extracts text** — name, description, tool names, tool descriptions
2. **Generates embeddings** — converts text to high-dimensional vectors using a sentence transformer model
3. **Stores vectors** — saves embeddings alongside the registration in DocumentDB

When you search:

1. **Query embedding** — your search text is converted to a vector using the same model
2. **Similarity search** — the gateway finds vectors closest to your query (cosine similarity)
3. **Ranking** — results are sorted by similarity score (higher = better match)

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  "what time     │────►│   Embedding     │────►│   [0.23, 0.87,  │
│   is it?"       │     │     Model       │     │    0.12, ...]   │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  currenttime    │◄────│   Similarity    │◄────│  Vector Search  │
│  server (0.92)  │     │    Ranking      │     │   (cosine)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

Embeddings capture semantic meaning — words and phrases with similar meanings produce similar vectors:

| Query | Semantically Similar To |
|-------|------------------------|
| "add a server" | "register service", "create server", "new registration" |
| "clock" | "current time", "what time is it", "timezone" |
| "book a flight" | "airline reservation", "travel booking" |

This is why you can search "add a server" and discover the `register_service` tool, or search "clock" and find the `currenttime` server — the embeddings understand semantic relationships between concepts, even without keyword overlap.

::alert[For a deeper dive into embedding models, vector similarity, and configuration options, see the [Deep Dive: How Embeddings Power Search](/module-2/deep-dive-embeddings) page.]{type="info"}

---

## Search and Access Control

Semantic search respects the same access control you explored in Lab 1. Different users see different results for the *same query*, because results are filtered server-side based on each user's scope.

| Query | Admin | LOB 1 | LOB 2 |
|-------|-------|-------|-------|
| `get the current time` | Current Time API | Current Time API | No match |
| `demo tools for testing` | Real Server Fake Tools | No match | Real Server Fake Tools |
| `find available tools` | AI Registry Tools | AI Registry Tools | AI Registry Tools |

The semantic search engine computes similarity scores for *all* registered resources, but the Registry API filters results to only include resources the user is authorized to see. Users cannot discover servers outside their scope, even with clever queries.

::alert[This is the same `ui_permissions.list_service` filtering you saw in Lab 1. Semantic search doesn't bypass access control — it works within it.]{type="info"}

---

## The intelligent_tool_finder

The AI Registry Tools server includes a special tool called `intelligent_tool_finder`. This is the same semantic search engine, exposed as an MCP tool that AI agents can invoke programmatically.

**Why it matters:** When an AI coding assistant (like Claude Code or Cursor) connects to the MCP Gateway, it can call `intelligent_tool_finder` to discover relevant tools at runtime — without hardcoding a list of available tools.

**Tool schema:**

:::code{language=json showCopyAction=false}
{
  "name": "intelligent_tool_finder",
  "description": "Find MCP tools using natural language queries",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Natural language description of what you need"
      },
      "limit": {
        "type": "integer",
        "description": "Maximum number of results (default: 5)"
      }
    },
    "required": ["query"]
  }
}
:::

**How AI agents use it:**

1. User asks the agent: "What's the current time in Seattle?"
2. Agent calls `intelligent_tool_finder` with query `"get current time for a timezone"`
3. Gateway returns matching tools with their servers and similarity scores
4. Agent invokes the best match (`current_time_by_timezone` on `currenttime`)
5. Result is returned to the user

This enables agents to work without hardcoded tool lists — they discover capabilities at runtime, and the gateway enforces the same access control as the UI.

::alert[You'll see `intelligent_tool_finder` in action when you integrate an AI coding assistant in a later lab.]{type="info"}

:button[Next: Register the Cloudflare Documentation Server]{href="/module-2/step-3-register-server"}
