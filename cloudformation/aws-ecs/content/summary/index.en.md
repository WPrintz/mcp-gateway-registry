---
title: "Summary"
weight: 130
---

## Workshop Complete!

You've successfully completed the MCP Gateway and Registry workshop. Here's a recap of what you learned.

---

## Modules Completed

| Module | Topic | Duration |
|--------|-------|----------|
| 1 | Getting Started | 20 min |
| 2 | Exploring the Registry | 45 min |
| 3 | Semantic Search | 30 min |
| 4 | Registering an MCP Server | 45 min |
| 5 | Direct MCP Connection | 30 min |
| 6 | Gateway Connection | 45 min |
| 7 | Dynamic Tool Discovery | 45 min |
| 8 | Bedrock AgentCore Integration | 60 min |
| 9 | A2A Communication | 45 min |
| 10 | Access Control with Keycloak | 45 min |
| 11 | Monitoring & Observability | 30 min |

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

### Protocols Covered

- **MCP**: Agent-to-tool communication
- **A2A**: Agent-to-agent delegation
- **OAuth2/OIDC**: Authentication and authorization

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
