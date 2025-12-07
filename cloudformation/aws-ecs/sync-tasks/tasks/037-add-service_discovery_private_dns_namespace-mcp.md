# Task 037: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/networking.tf`
- **Line**: 4
- **Address**: `module.mcp-gateway.aws_service_discovery_private_dns_namespace.mcp`
- **Type**: `aws_service_discovery_private_dns_namespace` → `AWS::ServiceDiscovery::PrivateDnsNamespace`

### TF Resource Block
```hcl
resource "aws_service_discovery_private_dns_namespace" "mcp" {
  name        = "${local.name_prefix}.local"
  description = "Service discovery namespace for MCP Gateway Registry"
  vpc         = var.vpc_id
  tags        = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Mcp:
    Type: AWS::ServiceDiscovery::PrivateDnsNamespace
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Mcp` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks