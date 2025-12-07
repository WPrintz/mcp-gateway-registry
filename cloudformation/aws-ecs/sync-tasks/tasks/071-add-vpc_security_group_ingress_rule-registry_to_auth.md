# Task 071: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/ecs-services.tf`
- **Line**: 510
- **Address**: `module.mcp-gateway.aws_vpc_security_group_ingress_rule.registry_to_auth`
- **Type**: `aws_vpc_security_group_ingress_rule` → `UNKNOWN:aws_vpc_security_group_ingress_rule`

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

## ⚠️ Unknown CFN Type

The Terraform type `aws_vpc_security_group_ingress_rule` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_vpc_security_group_ingress_rule`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `RegistryToAuth` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks