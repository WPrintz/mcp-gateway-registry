---
title: "Summary"
weight: 130
---

## Workshop Complete!

You've successfully completed the MCP Gateway and Registry workshop. Here's a recap of what you learned.

---

## Modules Completed

| Module | Topic | What You Did |
|--------|-------|-------------|
| 1 | UI Exploration and Basic Setup | Found CloudFormation outputs, logged in via Keycloak, toured the dashboard and Settings control plane |
| 2 | Registry Discovery and Server Registration | Compared keyword vs semantic search, registered the Cloudflare Documentation MCP server, verified it end-to-end |
| 3 | Fine-Grained Access Control | Logged in as LOB users to see multi-tenancy in action, explored three-layer enforcement (UI visibility, method access, tool permissions), managed groups and M2M accounts through IAM Settings |

---

## Key Concepts

### MCP Gateway Value Proposition

| Without Gateway | With Gateway |
|-----------------|--------------|
| Point-to-point integrations | Centralized governance |
| No visibility | Full audit trail |
| No access control | Group-based permissions |
| Manual discovery | Semantic search |
| No revocation | Instant access control |

### Three Layers of Access Control

| Layer | What It Controls | Example |
|-------|-----------------|---------|
| **UI Visibility** | Which server and agent cards appear in the dashboard | LOB 1 user sees 2 of 4 servers |
| **Method Access** | Which MCP protocol methods are allowed per server | A user may have `tools/list` but not `tools/call` |
| **Tool Permissions** | Which specific tools can be invoked via `tools/call` | LOB 1 can invoke `intelligent_tool_finder` but not the other 4 tools on AI Registry Tools |

### Protocols Covered

- **MCP**: Agent-to-tool communication
- **A2A**: Agent-to-agent delegation
- **OAuth2/OIDC**: Authentication and authorization (Keycloak, with support for Amazon Cognito and Microsoft Entra ID)

---

## Clean Up

### Workshop Studio Events

If you are running this workshop at an AWS-hosted event using Workshop Studio, **no cleanup is required**. All provisioned infrastructure and accounts are automatically deleted when the event ends.

### Running in Your Own Account

If you deployed the workshop in your own AWS account using the Terraform configuration, follow these steps to avoid ongoing charges:

1. **Run Terraform destroy:**
   ```bash
   cd terraform/aws-ecs
   terraform destroy
   ```
   Review the plan and confirm when prompted.

2. **Manually remove retained resources:** Terraform may not delete resources with retention policies or non-empty contents. After destroy completes, check for and remove:
   - **S3 buckets**: Empty and delete any buckets that were created with `force_destroy = false`
   - **CloudWatch Log Groups**: Delete `/ecs/mcp-gateway-*` log groups if no longer needed
   - **ECR repositories**: Delete container image repositories if they contain images

3. **Verify no resources remain:** Check the [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home#/cost-explorer) after 24 hours to confirm no unexpected charges.

::alert[Any resources that are not deleted will continue to incur costs in your AWS account. S3 storage, CloudWatch log retention, and ECR image storage are common sources of residual charges after stack deletion. Review your account for any remaining resources if you see unexpected costs.]{type="warning" header="Ongoing Cost Warning"}

---

## Next Steps

1. **Deploy in your environment**: Follow the [Installation Guide](https://agentic-community.github.io/mcp-gateway-registry/installation/) to deploy with Terraform
2. **Register your MCP servers**: Onboard existing tools
3. **Configure access control**: Set up groups and permissions
4. **Enable monitoring**: Set up dashboards and alerts

---

## Feedback

We'd love to hear your feedback on this workshop!

:button[Return to Home]{href="/"}
