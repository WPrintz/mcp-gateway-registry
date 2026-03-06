---
title: "Securing AI Agent Ecosystems with MCP Gateway and Registry"
weight: 0
---

## Workshop Overview

As organizations adopt AI agents and coding assistants, managing tool access becomes a critical challenge. Teams independently connect agents to various tools and APIs, creating ungoverned point-to-point integrations with no visibility, audit trails, or access control.

The **MCP Gateway and Registry** addresses this by providing a centralized governance layer for AI tool ecosystems--without replacing your existing MCP servers.

:image[MCP Sprawl vs Governed Access]{src="/static/img/mcp-gateway-registry-infographic.png" width=800}

---

## What You'll Learn

In this hands-on workshop, you'll explore a fully deployed MCP Gateway and Registry environment. Rather than deploying infrastructure, you'll focus on **using** the platform to understand its capabilities through strategic, enterprise-focused scenarios.

**Key skills you'll develop:**

- Navigate the Registry UI and understand multi-tenant access patterns
- Configure group-based access control for different lines of business
- Use semantic search to discover MCP servers and A2A agents
- Integrate AI coding assistants with the gateway
- Understand agent-to-agent (A2A) dynamic discovery
- Use the Administrative API for programmatic management
- Monitor usage with observability dashboards
- Evaluate security scanning for supply chain protection
- Configure federation with external registries

---

## Workshop Labs

### Foundation

| Lab | Topic | Duration |
|-----|-------|----------|
| [Lab 1](/module-1) | UI Exploration and Basic Setup | 20 min |
| [Lab 2](/module-2) | Discovery and Semantic Search | 40 min |
| [Lab 3](/module-3) | Fine-Grained Access Control | 30 min |

**Total workshop time:** ~90 minutes

::alert[Additional modules covering AI assistant integration, agent-to-agent discovery, administrative APIs, observability, security scanning, and federation are under development.]{type="info" header="More Labs Coming Soon"}

:button[Start Lab 1]{href="/module-1"}

---

## Cost

::alert[This workshop deploys resources that will incur costs in your AWS account. The estimated cost is approximately **$30 per day** while the environment is running. Be sure to clean up resources after completing the workshop to avoid ongoing charges.]{type="warning" header="Workshop Cost Warning"}

**Key services and their pricing pages:**

- [Amazon ECS](https://aws.amazon.com/ecs/pricing/) - Container hosting for gateway services
- [Amazon DocumentDB](https://aws.amazon.com/documentdb/pricing/) - Database for registry storage
- [Amazon Managed Service for Prometheus](https://aws.amazon.com/prometheus/pricing/) - Metrics collection
- Grafana OSS -- runs as an ECS Fargate task (included in ECS costs above)
- [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/pricing/) - Traffic routing

---

## Supported Regions

This workshop is available in the following AWS regions:

- **US East (N. Virginia)** - `us-east-1`
- **US East (Ohio)** - `us-east-2`
- **US West (Oregon)** - `us-west-2`
- **Europe (Frankfurt)** - `eu-central-1`
- **Europe (Ireland)** - `eu-west-1`
- **Europe (London)** - `eu-west-2`
- **Asia Pacific (Sydney)** - `ap-southeast-2`
- **Asia Pacific (Mumbai)** - `ap-south-1`
- **South America (Sao Paulo)** - `sa-east-1`

---

## Prerequisites

- Basic understanding of AI agents and how they use tools
- Familiarity with OAuth 2.0 concepts (helpful but not required)
- Access to the AWS Console via Workshop Studio

::alert[All infrastructure is pre-deployed for you. This workshop focuses on using and understanding the MCP Gateway, not deploying it.]{type="info" header="No Infrastructure Setup Required"}

---

## Running in Your Own Account

If you want to deploy the MCP Gateway and Registry outside of a Workshop Studio event, the project is open source and includes Terraform-based deployment instructions.

1. Clone the repository: [MCP Gateway Registry on GitHub](https://github.com/agentic-community/mcp-gateway-registry)
2. Follow the [Installation Guide](https://agentic-community.github.io/mcp-gateway-registry/installation/) for deployment instructions
3. The Terraform configuration under `terraform/aws-ecs/` deploys the full stack to your own AWS account
4. See the [Teardown Guide](https://agentic-community.github.io/mcp-gateway-registry/installation/) for cleanup instructions to avoid ongoing costs

::alert[When running in your own account, you are responsible for all AWS costs incurred. See the [Cost](#cost) section above for estimated pricing.]{type="warning" header="Cost Responsibility"}

---

## Who Should Take This Workshop

- **Enterprise Architects** evaluating governance solutions for AI tool ecosystems
- **Platform Engineers** who will operate and manage MCP infrastructure
- **Application Developers** integrating AI agents with enterprise tools
- **Security and Compliance Teams** assessing AI tool access controls and audit capabilities

:button[Learn About the Architecture]{href="/introduction"}
