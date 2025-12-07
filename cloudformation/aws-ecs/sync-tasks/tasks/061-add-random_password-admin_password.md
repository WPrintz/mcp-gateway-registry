# Task 061: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 10
- **Address**: `module.mcp-gateway.random_password.admin_password`
- **Type**: `random_password` → `UNKNOWN:random_password`

### TF Resource Block
```hcl
resource "random_password" "admin_password" {
  length      = 32
  special     = true
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}
```

## ⚠️ Unknown CFN Type

The Terraform type `random_password` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `random_password`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `AdminPassword` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks