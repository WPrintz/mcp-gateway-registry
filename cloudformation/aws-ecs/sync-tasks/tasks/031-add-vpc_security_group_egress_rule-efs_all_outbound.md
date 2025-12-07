# Task 031: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/storage.tf`
- **Line**: 168
- **Address**: `module.mcp-gateway.aws_vpc_security_group_egress_rule.efs_all_outbound`
- **Type**: `aws_vpc_security_group_egress_rule` → `AWS::EC2::SecurityGroupEgress`

### TF Resource Block
```hcl
resource "aws_vpc_security_group_egress_rule" "efs_all_outbound" {
  security_group_id = module.efs.security_group_id

  description = "Allow all outbound"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${local.name_prefix}-efs-all-outbound"
    }
  )
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  EfsAllOutbound:
    Type: AWS::EC2::SecurityGroupEgress
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `EfsAllOutbound` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks