# Task 059: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/storage.tf`
- **Line**: 168
- **Address**: `module.mcp-gateway.aws_vpc_security_group_egress_rule.efs_all_outbound`
- **Type**: `aws_vpc_security_group_egress_rule` → `UNKNOWN:aws_vpc_security_group_egress_rule`

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

## ⚠️ Unknown CFN Type

The Terraform type `aws_vpc_security_group_egress_rule` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_vpc_security_group_egress_rule`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `EfsAllOutbound` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks