# Task 038: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/ecs-services.tf`
- **Line**: 510
- **Address**: `module.mcp-gateway.aws_vpc_security_group_ingress_rule.registry_to_auth`
- **Type**: `aws_vpc_security_group_ingress_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_vpc_security_group_ingress_rule" "registry_to_auth" {
  security_group_id            = module.ecs_service_auth.security_group_id
  referenced_security_group_id = module.ecs_service_registry.security_group_id
  from_port                    = 8888
  to_port                      = 8888
  ip_protocol                  = "tcp"
  description                  = "Allow registry to access auth server"

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  RegistryToAuth:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `RegistryToAuth` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks