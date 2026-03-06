---
title: "Lab 1: UI Exploration and Basic Setup"
weight: 20
---

In this lab, you'll access the pre-deployed MCP Gateway & Registry environment and explore the platform's interface. The workshop comes pre-configured with line-of-business users and different MCP servers, allowing you to immediately see what's available.

**Estimated Time:** 30 minutes

## What You'll Learn

- How to find CloudFormation outputs for accessing the deployed services
- How to access the MCP Gateway Registry UI via CloudFront HTTPS
- How to authenticate using Keycloak with different user accounts
- The layout and key sections of the dashboard
- What MCP servers and A2A agents are pre-registered
- The Settings control plane: audit logging, federation, virtual MCP servers, IAM, and system configuration

## Prerequisites

- Access to the AWS Console via Workshop Studio
- Workshop environment fully deployed (this is done for you)

## Scenario

You're an enterprise architect evaluating the MCP Gateway and Registry for your organization. Multiple lines of business have been set up with different access levels, and several MCP servers and A2A agents have been pre-registered. Your goal is to understand what the platform offers before diving into specific capabilities.

## Pre-Configured Environment

The workshop environment includes these pre-deployed components:

| Component | Purpose | Access Method |
|-----------|---------|---------------|
| **MCP Gateway Registry** | Central UI for managing MCP servers and agents | CloudFront HTTPS |
| **Auth Server** | OAuth2/OIDC token generation and validation | Internal (via Registry) |
| **Keycloak** | Identity management, user authentication, group-based access | CloudFront HTTPS |
| **Sample MCP Servers** | Pre-registered tools (CurrentTime, MCPGW, RealServerFakeTools) | Via Gateway |
| **Sample A2A Agents** | Travel Assistant, Flight Booking agents | Via Registry |

### Pre-Configured Users

| User | Role | Visible Servers | Access Level |
|------|------|-----------------|--------------|
| `admin` | Platform Admin | All servers | Full admin — manage servers, agents, users |
| `testuser` | Developer | All servers | Read and execute — can browse and call tools |
| `lob1-user` | LOB 1 User | Current Time API, AI Registry Tools | Scoped to LOB 1 servers and tools only |
| `lob2-user` | LOB 2 User | Real Server Fake Tools, AI Registry Tools | Scoped to LOB 2 servers and tools only |

::alert[All services are accessed via CloudFront HTTPS URLs. No custom domain or DNS configuration is required.]{type="info"}

## Steps

::children
