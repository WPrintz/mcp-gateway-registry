---
title: "MCP and A2A Protocols"
weight: 12
---

## Model Context Protocol (MCP)

MCP is an open protocol that standardizes how AI applications connect to external tools and data sources. Instead of building custom integrations for each tool, developers implement the MCP specification once and gain access to a growing ecosystem of compatible servers.

**Key concepts:**

| Concept | Description |
|---------|-------------|
| **MCP Server** | Exposes tools, prompts, and resources via a standard interface |
| **MCP Client** | AI applications (agents, coding assistants) that consume MCP servers |
| **Tools** | Functions that agents can invoke (e.g., `get_weather`, `search_database`, `create_ticket`) |
| **Resources** | Data sources that agents can read (files, databases, APIs) |
| **Prompts** | Pre-defined prompt templates that servers can provide |

### How MCP Works

```
┌─────────────────┐     MCP Protocol      ┌─────────────────┐
│   AI Agent      │◄─────────────────────►│   MCP Server    │
│  (MCP Client)   │   JSON-RPC over       │  (Tools/Data)   │
│                 │   HTTP/SSE/stdio      │                 │
└─────────────────┘                       └─────────────────┘
```

The agent discovers available tools, then invokes them as needed to complete tasks. The protocol handles:
- Tool discovery and schema introspection
- Request/response serialization
- Streaming for long-running operations

### MCP Protocol Examples

**Tool Discovery Request** - The client asks the server what tools are available:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
:::

**Tool Discovery Response** - The server returns available tools with their schemas:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "get_current_time",
        "description": "Get the current time for a specific timezone",
        "inputSchema": {
          "type": "object",
          "properties": {
            "timezone": {
              "type": "string",
              "description": "IANA timezone name (e.g., America/New_York)"
            }
          },
          "required": ["timezone"]
        }
      }
    ]
  }
}
:::

**Tool Invocation Request** - The client calls a tool with parameters:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_current_time",
    "arguments": {
      "timezone": "America/Los_Angeles"
    }
  }
}
:::

**Tool Invocation Response** - The server returns the result:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "The current time in America/Los_Angeles is 2025-01-15 14:30:00 PST"
      }
    ]
  }
}
:::

### Python Client Example

Here's how an MCP client connects to a server and invokes a tool:

:::code{language=python showCopyAction=false}
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

async def call_mcp_tool():
    # Connect to the MCP server
    async with streamablehttp_client(url="http://localhost:8001/mcp") as (read, write, _):
        async with ClientSession(read, write) as session:
            # Initialize the connection
            await session.initialize()
            
            # Discover available tools
            tools = await session.list_tools()
            print(f"Available tools: {[t.name for t in tools.tools]}")
            
            # Call a specific tool
            result = await session.call_tool(
                "get_current_time", 
                arguments={"timezone": "America/Los_Angeles"}
            )
            print(f"Result: {result.content[0].text}")
:::

---

## Agent-to-Agent (A2A) Protocol

A2A extends the ecosystem by enabling agents to discover and delegate tasks to other agents. A travel planning agent might discover and invoke a flight booking agent, which in turn uses MCP tools to search and book flights.

**Key concepts:**

| Concept | Description |
|---------|-------------|
| **Agent Registry** | Directory of available agents and their capabilities |
| **Agent Cards** | Metadata describing what an agent can do (skills, trust level, protocols) |
| **Delegation** | One agent invoking another to complete a subtask |
| **Trust Levels** | Community, Verified, or Trusted—indicating confidence in the agent |

### A2A in Action

```
┌─────────────────┐                       ┌─────────────────┐
│ Travel Planning │──── "Book flight" ───►│ Flight Booking  │
│     Agent       │                       │     Agent       │
└─────────────────┘                       └────────┬────────┘
                                                   │
                                                   │ MCP
                                                   ▼
                                          ┌─────────────────┐
                                          │  Airline API    │
                                          │  (MCP Server)   │
                                          └─────────────────┘
```

The Travel Planning agent doesn't need to know how to book flights—it delegates to a specialized agent that has that capability.

### A2A Protocol Examples

**Agent Card** - Metadata describing an agent's capabilities:

:::code{language=json showCopyAction=false}
{
  "name": "flight-booking-agent",
  "description": "Books flights and manages reservations",
  "url": "https://agents.example.com/flight-booking",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": false
  },
  "skills": [
    {
      "id": "book-flight",
      "name": "Book Flight",
      "description": "Search and book flights between destinations",
      "inputModes": ["text"],
      "outputModes": ["text"]
    },
    {
      "id": "check-status",
      "name": "Check Flight Status",
      "description": "Get real-time status of a booked flight"
    }
  ],
  "authentication": {
    "schemes": ["bearer"]
  },
  "trustLevel": "verified"
}
:::

**Task Request** - One agent delegating a task to another:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": "task-123",
  "method": "tasks/send",
  "params": {
    "id": "task-123",
    "message": {
      "role": "user",
      "parts": [
        {
          "type": "text",
          "text": "Book a flight from Seattle to New York on January 20th"
        }
      ]
    }
  }
}
:::

**Task Response** - The delegated agent returns results:

:::code{language=json showCopyAction=false}
{
  "jsonrpc": "2.0",
  "id": "task-123",
  "result": {
    "id": "task-123",
    "status": {
      "state": "completed"
    },
    "artifacts": [
      {
        "name": "booking-confirmation",
        "parts": [
          {
            "type": "text",
            "text": "Flight booked: SEA → JFK on Jan 20, 2025. Confirmation: ABC123"
          }
        ]
      }
    ]
  }
}
:::

---

## Why These Protocols Matter

**Interoperability**: Any MCP-compatible client can use any MCP-compatible server. No vendor lock-in.

**Composability**: Agents can be composed from smaller, specialized agents and tools.

**Discoverability**: Agents can find tools and other agents at runtime, rather than requiring hardcoded configurations.

**Governance**: With a standard protocol, you can add a governance layer (the gateway) without modifying individual tools or agents.

---

## Learn More

- [A2A Protocol Support](https://agentic-community.github.io/mcp-gateway-registry/a2a/) - Complete guide to agent-to-agent communication
- [Dynamic Tool Discovery](https://agentic-community.github.io/mcp-gateway-registry/dynamic-tool-discovery/) - How agents discover and invoke MCP tools
- [MCP Specification](https://modelcontextprotocol.io/) - Official Model Context Protocol documentation
